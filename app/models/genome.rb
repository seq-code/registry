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

    def important_sample_attributes
      {
        date: %i[collection_date event_date_time_start event_date_time_end],
        location: %i[
          lat_lon lat lon
          geographic_location_latitude geographic_location_longitude
          latitude_start latitude_end longitude_start longitude_end
        ],
        toponym: %i[
          geo_loc_name geographic_location_country_and_or_sea marine_region
        ],
        environment: %i[
          env_material sample_type env_biome isolation_source analyte_type
          env_broad_scale env_local_scale env_medium
          environment_biome environment_feature gold_ecosystem_classification
          broad_scale_environmental_context local_environmental_context
          environmental_medium
        ],
        other: %i[
          host ph depth temp temperature rel_to_oxygen geographic_location_depth
          chlorophyll isol_growth_condt
        ],
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

  ##
  # Finds the locations of all source samples associated to this genome, and
  # returns them as an Array of 2-element Arrays ([lat, lon]) or +nil+
  def source_sample_locations
    coord = /([-+] *)?(\d+(?:[\.\,]\d+)?|\d+°(?:\d+['"])*)( *[NSEW])?/
    keys = {
      lat: %i[lat geographic_location_latitude latitude_start latitude_end],
      lon: %i[lon geographic_location_longitude longitude_start longitude_end]
    }

    coords = { lat: nil, lon: nil }
    @_source_sample_locations ||=
      source_cannonical_samples.map do |sample|
        # Try joint keys
        if sample[:lat_lon]
          m = sample[:lat_lon].match(/^ *(#{coord})[ ,;\/\-]+(#{coord}) *$/i)
          m ||= []
          coords[:lat] = m[2..4]
          coords[:lon] = m[6..8]
        end

        # Try individual keys
        if coords.values.any?(&:nil?)
          keys.each do |dim, list|
            list.each do |key|
              if sample[key]
                m = sample[key].match(/^#{coord}$/i) || []
                coords[dim] = m[1..3]
              end
              break unless coords[dim].nil?
            end
          end
        end

        # Parse each coordinate
        if coords.values.any?(&:nil?)
          nil
        else
          coords.map do |k, v|
            v.map!(&:to_s).map!(&:strip)
            decimal =
              if m = v[1].match(/^(\d) *°(?: *(\d+) *'(?: *(\d+) *(?:"|''))?)?/)
                m[1].to_f + (m[2].to_f + m[3].to_f / 60) / 60
              else
                v[1].gsub(',', '.').to_f
              end

            if %w[S s W w].include?(v[2]) || v[0] == '-'
              -decimal
            else
              decimal
            end
          end
        end
      end
  end

  ##
  # Finds the rectangular bounds of all sample locations, with a minimum range
  # of latitudes and longitudes of +min+ after expanding both by a factor of
  # +pad+, and returns it as an Array in the [south, west, north, east] order
  def source_sample_area(min = 0.1, pad = 0.5)
    loc = source_sample_locations.compact
    return unless loc.present?

    rng = {
      lat: loc.map { |i| i[0] }.minmax,
      lon: loc.map { |i| i[1] }.minmax
    }

    rng.each do |k, v|
      width = v.inject(:-).abs
      v[0] -= width * pad / 2
      v[1] += width * pad / 2
      width = v.inject(:-).abs
      if width < min
        pad_extra = (min - width) / 2
        rng[k][0] -= pad_extra
        rng[k][1] += pad_extra
      end
    end

    [rng[:lat][0], rng[:lon][0], rng[:lat][1], rng[:lon][1]]
  end

  ##
  # TODO
  # Use source_cannonical_samples instead!
  def source_attributes
    return unless source_hash
    return @source_attributes if @source_attributes

    not_provided = [
      'not provided', 'not collected', 'unavailable', 'not applicable',
      'missing', '-', 'n/a', 'null'
    ]
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

  def source_cannonical_samples
    not_provided = [
      'not provided', 'unavailable', 'missing', 'not applicable',
      '-', 'n/a', 'null'
    ]   
    @_source_cannonical_samples ||=
      source_hash[:samples].each_value.map do |sample|
        Hash[
          sample[:attributes].map do |key, value|
            value.strip!
            nice_key = key.to_s.downcase.gsub(/[^A-Za-z0-9]/, '_')
                          .gsub(/_+/, '_').gsub(/^_|_$/, '').to_sym
            if value.present? && !not_provided.include?(value.downcase)
              [nice_key, value]
            end
          end.compact
        ]
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
