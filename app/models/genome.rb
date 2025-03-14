class Genome < ApplicationRecord
  belongs_to(
    :updated_by, optional: true,
    class_name: 'User', foreign_key: 'updated_by_id'
  )
  belongs_to(:strain, optional: true)
  has_many(:genome_sequencing_experiments, dependent: :destroy)
  has_many(:sequencing_experiments, through: :genome_sequencing_experiments)
  has_many(
    :typified_names, class_name: 'Name',
    as: :nomenclatural_type, dependent: :nullify
  )

  before_validation(:standardize_source)
  after_save(:monitor_source_changes)
  after_save(:link_sequencing_experiments!)

  validates(:database, presence: true)
  validates(:accession, presence: true)
  validates(
    :kind, inclusion: { in: %w[isolate enrichment mag sag] }, if: :kind?
  )
  validates(:seq_depth, numericality: { greater_than: 0.0 }, if: :seq_depth?)
  validates(:source_accession, presence: true, if: :source?)
  validates(:source_database, presence: true, if: :source?)
  validates(:accession, uniqueness: { scope: :database })

  has_rich_text(:submitter_comments)

  before_destroy(:remove_miga!)

  include HasExternalResources
  include Genome::ExternalResources
  include Genome::SampleSet

  attr_accessor :queue_for_source_update

  class << self
    def find_or_create(database, accession)
      if database.present? && accession.present?
        find_or_create_by(database: database, accession: accession)
      end
    end

    def db_names
      {
        nuccore: 'INSDC Nucleotide',
        assembly: 'NCBI Assembly'
      }
    end

    def kinds
      {
        mag: { name: 'Metagenome-Assembled Genome (MAG)', miga: 'popgenome' },
        sag: { name: 'Single-Cell Amplified Genome (SAG)', miga: 'scgenome' },
        enrichment: { name: 'Enrichment Genome', miga: 'popgenome' },
        isolate: { name: 'Isolate Genome', miga: 'genome' }
      }
    end

    def kinds_opt
      kinds.map { |k, v| [v[:name], k] }
    end

    def source_databases
      {
        sra: { name: 'INSDC Sequence Read Archive (SRA)', display: 'SRA' },
        biosample: { name: 'INSDC BioSample', display: 'BioSample' }
      }
    end

    def source_databases_opt
      source_databases.map { |k, v| [v[:name], k] }
    end

    def required
      %i[
        kind? source_database? source_accession?
      ]
    end
  end
  
  @@FIELDS_WITH_AUTO = %i[
    gc_content completeness contamination most_complete_16s number_of_16s
    most_complete_23s number_of_23s number_of_trnas quality
    coding_density n50 contigs largest_contig assembly_length
    ambiguous_fraction codon_table
  ]
  def self.fields_with_auto
    @@FIELDS_WITH_AUTO
  end

  Genome.kinds.keys.each do |k, v|
    define_method("#{k}?") do
      kind? && kind == k.to_s
    end
  end

  ##
  # Returns names linked to the strain of the genome (but not directly typified
  # by the genome)
  def referenced_names
    @referenced_names ||= strain.try(:typified_names) || []
  end

  def names
    @names ||= typified_names + referenced_names
  end

  ##
  # Attempts to update the accession of the genome and all associated names.
  # If passed, it can also update the database. Please use with caution!
  # 
  # TODO
  # This function should be deprecated, as the new system of nomenclatural types
  # makes it superfluous
  def update_accession(new_accession, new_database = nil)
    new_database = database unless new_database.present?
    self.class.transaction do
      update(accession: new_accession, database: new_database)
    end
  end

  def kind_hash
    kind ? self.class.kinds[kind.to_sym] : nil
  end

  def kind_name
    (kind_hash || {})[:name]
  end

  def kind_miga
    (kind_hash || {})[:miga]
  end

  %w[mag sag enrichment isolate].each do |i|
    define_method(:"#{i}?") do
      kind? && kind.to_s == i
    end
  end

  def mag_or_sag?
    mag? || sag? || enrichment?
  end

  def source?
    source_accession? && source_database?
  end

  def source_accessions
    source_accession.try(:split, /, */)
  end

  def rrnas_or_trnas?
    number_of_16s_any.present? ||
      number_of_23s_any.present? ||
      number_of_trnas_any.present?
  end

  def source_database_display
    self.class.source_databases.dig(source_database.to_sym, :display)
  end

  def source_database_name
    self.class.source_databases.dig(source_database.to_sym, :name)
  end

  def source_text(acc = nil)
    acc ||= source_accession
    return '' unless source?

    "#{source_database_display}: #{acc}"
  end

  def source_link(acc = nil)
    acc ||= source_accession if source?
    return unless acc

    case source_database
    when 'sra'
      "https://www.ncbi.nlm.nih.gov/sra/#{acc}[accn]"
    when 'biosample'
      "https://www.ncbi.nlm.nih.gov/biosample/#{acc}"
    end
  end

  def source_links
    return [] unless source?
    source_accessions.map do |acc|
      [source_link(acc), source_text(acc), source_database_name]
    end
  end

  ##
  # Returns registered BioSample accessions, directly from the database
  # if the source database is +:biosample+, or through the external links
  # if it is +:sra+
  def biosample_accessions
    case source_database.try(:to_sym)
    when :sra
      source_hash.try(:dig, :samples).try(:keys) || []
    when :biosample
      source_accessions
    end
  end

  ##
  # Returns all BioSample accessions, including secondary (alternative)
  # accessions
  def biosample_accessions_all
    (source_hash.try(:dig, :samples) || {}).values.map do |sample|
      sample[:biosample_accessions] || []
    end.flatten.uniq.select(&:present?)
  end

  def sra_accessions
    case source_database.to_sym
    when :sra
      source_accessions.unique
    when :biosample
      SequencingExperiment.by_biosample(source_accessions)
        .pluck(:sra_accession).unique
    end
  end

  def link(acc = nil)
    acc ||= accession
    case database
    when 'assembly'
      "https://www.ncbi.nlm.nih.gov/datasets/genome/#{acc}"
    when 'nuccore'
      "https://www.ncbi.nlm.nih.gov/#{database}/#{acc}"
    end
  end

  def links
    @links ||= Hash[accession.split(/ *, */).map { |i| [i, link(i)] }]
  end

  def db_name
    self.class.db_names[database.to_sym]
  end

  def type_of_type
    db_name
  end

  def text
    "#{db_name}: #{accession}"
  end

  def display(_html = true)
    text
  end

  def title(prefix = nil)
    prefix ||= 'Genome '
    '%ssc|%07i' % [prefix, id]
  end

  def seqcode_url(protocol = true)
    "#{'https://' if protocol}seqco.de/g:#{id}"
  end

  def uri
    seqcode_url
  end

  def quality
    return nil unless completeness? && contamination?

    (completeness - 5 * contamination).round(2)
  end

  def quality_auto
    return nil unless completeness_auto? && contamination_auto?

    (completeness_auto - 5 * contamination_auto).round(2)
  end

  # Dummy methods returning +nil+
  attr_accessor *%i[
    coding_density n50 contigs largest_contig assembly_length
    ambiguous_fraction codon_table
  ]

  @@FIELDS_WITH_AUTO.each do |i|
    # Redefine to consider valid estimates of 0 or 0.0
    define_method(:"#{i}?") do
      send(i).present?
    end

    # Redefine to consider valid estimates of 0 or 0.0
    define_method(:"#{i}_auto?") do
      send(:"#{i}_auto").present?
    end

    # Find whichever is defined
    define_method(:"#{i}_any") do
      send(i) || send(:"#{i}_auto")
    end

    # Is any defined?
    define_method(:"#{i}_any?") do
      send(:"#{i}?") || send(:"#{i}_auto?")
    end
  end

  def complete?
    self.class.required.all? { |i| send(i) }
  end

  def can_edit?(user)
    (names.empty? && user.present?) ||
      names.all? { |name| name.can_edit?(user) }
  end

  # MiGA Checks

  def miga_name
    "genome_#{id}"
  end

  def miga_url
    miga_project = 'https://disc-genomics.uibk.ac.at/miga/projects/3'
    '%s/reference_datasets/genome_%i' % [miga_project, id]
  end

  def remove_miga!
    require 'miga'
    require 'miga/cli'

    MiGA::Cli.new([
      'rm', '--project', File.join(Rails.root, '..', 'miga_check'),
      '--dataset', miga_name, '--remove'
    ]).launch(false)
  end

  def recalculate_miga!
    err = remove_miga!
    # return false if err.is_a? Exception
    update(auto_scheduled_at: nil, auto_failed: nil, auto_check: false)
  end

  def link_sequencing_experiments!
    self.class.transaction do
      # Unlink experiments that shouldn't be here
      sequencing_experiments.each do |experiment|
        unless biosample_accessions.include?(experiment.biosample_accession) ||
               biosample_accessions.include?(experiment.biosample_accession_2)
          GenomeSequencingExperiment
            .where(genome: self, sequencing_experiment: experiment)
            .map(&:destroy!)
        end
      end

      # Link experiments that should be here
      self.sequencing_experiments +=
        SequencingExperiment
          .where(biosample_accession: biosample_accessions_all)
          .where.not(id: sequencing_experiments.pluck(:id))
      self.sequencing_experiments +=
        SequencingExperiment
          .where(biosample_accession_2: biosample_accessions_all)
          .where.not(id: sequencing_experiments.pluck(:id))
    end
  end

  def old_type_definition
    [database, accession]
  end

  private

  def standardize_source
    if source_accession
      self.source_accession.strip!
      self.source_accession.gsub!(/,? and /, ',')
      self.source_accession.gsub!(/( *, *)+/, ', ')
    end
    self.source_json = nil unless source?
    self.queue_for_source_update =
      source_database_changed? || source_accession_changed?
  end

  def monitor_source_changes
    queue_for_external_resources if queue_for_source_update
  end
end
