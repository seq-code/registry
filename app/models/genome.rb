class Genome < ApplicationRecord
  belongs_to(
    :updated_by, optional: true,
    class_name: 'User', foreign_key: 'updated_by_id'
  )

  before_validation(:standardize_source)
  after_save(:monitor_source_changes)

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

  include HasExternalResources
  include Genome::ExternalResources

  attr_accessor :queue_for_source_update

  class << self
    def find_or_create(database, accession)
      if database.present? && accession.present?
        find_or_create_by(database: database, accession: accession)
      end
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

    def important_sample_attributes
      {
        date: %i[collection_date],
        location: %i[
          lat_lon lat lon
          geographic_location_latitude geographic_location_longitude
        ],
        toponym: %i[
          geo_loc_name geographic_location_country_and_or_sea
        ],
        environment: %i[
          env_material sample_type env_biome isolation_source
          env_broad_scale env_local_scale env_medium
          environment_biome environment_feature gold_ecosystem_classification
          broad_scale_environmental_context local_environmental_context
          environmental_medium
        ],
        other: %i[host ph depth temp temperature rel_to_oxygen],
        package: %i[
          ncbi_package ena_checklist ncbi_submission_package biosamplemodel
        ]
      }
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

  def names
    @names ||=
      Name.where(type_material: database, type_accession: accession)
      .or(Name.where(genome_id: id))
  end

  def multiple_names?
    names.count > 1
  end

  ##
  # Attempts to update the accession of the genome and all associated names.
  # If passed, it can also update the database. Please use with caution!
  def update_accession(new_accession, new_database = nil)
    new_database = database unless new_database.present?
    self.class.transaction do
      g_par = { type_accession: new_accession, type_material: new_database }
      names.each { |name| name.update(g_par) or return false }
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

  def source_extra_biosamples
    return [] unless source_hash
    return @source_extra_biosamples if @source_extra_biosamples

    @source_extra_biosamples = []
    %i[derived_from sample_derived_from].each do |attribute|
      next unless attr = source_attributes[attribute]

      attr.each do |i|
        @source_extra_biosamples +=
          i.gsub(/.*: */, '').gsub(/[\.]/, '').split(/ *,(?: and)? */)
      end
    end
    @source_extra_biosamples.uniq!
    @source_extra_biosamples -= source_hash[:samples].keys.map(&:to_s)
    @source_extra_biosamples -= source_accessions
    @source_extra_biosamples
  end

  def source_attribute_groups
    return {} unless source_hash
    return @source_attribute_groups if @source_attribute_groups

    @source_attribute_groups = {}
    self.class.important_sample_attributes.each do |group, attributes|
      @source_attribute_groups[group] = {}
      attributes.each do |attribute|
        attr = source_attributes[attribute]
        @source_attribute_groups[group][attribute] = attr if attr.present?
      end
    end
    @source_attribute_groups
  end

  def source_attributes
    return unless source_hash
    return @source_attributes if @source_attributes

    not_provided = ['not provided', 'unavailable', 'missing']
    @source_attributes = {}
    source_hash[:samples].each_value do |sample|
      sample[:attributes].each do |key, value|
        value.strip!
        nice_key = key.to_s.downcase.gsub(/[^A-Za-z0-9]/, '_')
                      .gsub(/_+/, '_').gsub(/^_|_$/, '').to_sym
        if value.present? && !not_provided.include?(value.downcase)
          @source_attributes[nice_key] ||= []
          @source_attributes[nice_key] << value
        end
      end if sample[:attributes].present?
    end
    @source_attributes.each_value(&:uniq!)
    @source_attributes
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

  def db_text
    Name.type_material_name(database)
  end

  def text
    "#{db_text}: #{accession}"
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

  def recalculate_miga!
    require 'miga'
    require 'miga/cli'

    err = MiGA::Cli.new([
      'rm', '--project', File.join(Rails.root, '..', 'miga_check'),
      '--dataset', miga_name, '--remove'
    ]).launch(false)
    # return false if err.is_a? Exception

    update(auto_scheduled_at: nil, auto_failed: nil, auto_check: false)
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
