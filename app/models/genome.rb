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
        completeness_any contamination_any most_complete_16s_any
        number_of_16s_any number_of_trnas_any
      ]
    end

    def important_sample_attributes
      {
        date: %i[collection_date],
        location: %i[lat_lon lat lon],
        toponym: %i[geo_loc_name],
        environment: %i[
          env_material sample_type env_biome isolation_source
          env_broad_scale env_local_scale env_medium
        ],
        other: %i[host ph depth temp temperature]
      }
    end
  end
  
  @@FIELDS_WITH_AUTO = %i[
    gc_content completeness contamination most_complete_16s number_of_16s
    most_complete_23s number_of_23s number_of_trnas quality
    coding_density n50 contigs assembly_length ambiguous_fraction codon_table
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
    source_accession.split(/, */).map do |acc|
      [source_link(acc), source_text(acc), source_database_name]
    end
  end

  def source_extra_biosamples
    return [] unless source_hash
    return @source_extra_biosamples if @source_extra_biosamples

    @source_extra_biosamples = []
    %i[derived_from].each do |attribute|
      next unless attr = source_attributes[attribute]
      @source_extra_biosamples +=
        attr.gsub(/.*: */, '').gsub(/[\.]/, '').split(/ *, (?:and)? */)
    end
    @source_extra_biosamples.uniq!
    @source_extra_biosamples -= source_hash[:samples].keys.map(&:to_s)
  end

  def source_attribute_groups
    return {} unless source_hash
    return @source_attribute_groups if @source_attribute_groups

    @source_attribute_groups = {}
    self.class.important_sample_attributes.each do |group, attributes|
      @source_attribute_groups[group] = {}
      attributes.each do |attribute|
        next unless attr = source_attributes[attribute]
        @source_attribute_groups[group][attribute] = attr
      end
    end
    @source_attribute_groups
  end

  def source_attributes
    return unless source_hash
    return @source_attributes if @source_attributes

    @source_attributes = {}
    source_hash[:samples].each_value do |sample|
      sample[:attributes].each do |key, value|
        nice_key = key.to_s.downcase.gsub(/[- ]/, '_').to_sym
        value.strip!
        if value.present?
          @source_attributes[nice_key] ||= []
          @source_attributes[nice_key] << value
        end
      end
    end
    @source_attributes.each_value(&:uniq!)
    @source_attributes
  end

  def link
    case database
    when 'assembly'
      "https://www.ncbi.nlm.nih.gov/datasets/genome/#{accession}"
    when 'nuccore'
      "https://www.ncbi.nlm.nih.gov/#{database}/#{accession}"
    end
  end

  def text
    "#{Name.type_material_name(database)}: #{accession}"
  end

  def title
    'Genome sc|%07i' % id
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
    coding_density n50 contigs assembly_length ambiguous_fraction codon_table
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

  private

  def standardize_source
    self.source_accession.strip!
    self.source_accession.gsub!(/,? and /, ',')
    self.source_accession.gsub!(/( *, *)+/, ', ')
    self.source_json = nil unless source?
    self.queue_for_source_update =
      source_database_changed? || source_accession_changed?
  end

  def monitor_source_changes
    queue_for_external_resources if queue_for_source_update
  end
end
