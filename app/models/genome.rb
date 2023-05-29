class Genome < ApplicationRecord
  validates(:database, presence: true)
  validates(:accession, presence: true)
  validates(
    :kind, inclusion: { in: %w[isolate enrichment mag sag] }, if: :kind?
  )
  validates(:seq_depth, numericality: { greater_than: 0.0 }, if: :seq_depth?)
  validates(:source_accession, presence: true, if: :source?)
  validates(:source_database, presence: true, if: :source?)

  has_rich_text(:submitter_comments)

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
  end
  
  @@FIELDS_WITH_AUTO = %i[
    gc_content completeness contamination most_complete_16s number_of_16s
    most_complete_23s number_of_23s number_of_trnas quality
    coding_density n50 contigs assembly_length ambiguous_fraction codon_table
  ]
  def self.fields_with_auto
    @@FIELDS_WITH_AUTO
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
      "https://www.ncbi.nlm.nih.gov/sra/#{acc}"
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

  def link
    case database
    when 'assembly', 'nuccore'
      "https://www.ncbi.nlm.nih.gov/#{database}/#{accession}"
    end
  end

  def text
    "#{Name.type_material_name(database)}: #{accession}"
  end

  def updated_by_user
    User.find(updated_by) if updated_by?
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
end
