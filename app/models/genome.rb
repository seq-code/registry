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
        sra: { name: 'INSDC Sequence Read Archive (SRA)' },
        biosample: { name: 'INSDC BioSample' }
      }
    end

    def source_databases_opt
      source_databases.map { |k, v| [v[:name], k] }
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
    self.class.kinds[kind.to_sym]
  end

  def kind_name
    kind_hash[:name]
  end

  def source?
    source_accession? || source_database?
  end

  def rrnas_or_trnas?
    number_of_16s_any.present? ||
      number_of_23s_any.present? ||
      number_of_trnas_any.present?
  end

  def source_text
    source? ? "#{source_database}: #{source_accession}" : ''
  end

  def source_link
    case source_database
    when 'sra'
      "https://www.ncbi.nlm.nih.gov/biosample/#{source_accession}"
    when 'biosample'
      "https://www.ncbi.nlm.nih.gov/sra/#{source_accession}"
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
    completeness - 5 * contamination
  end

  def quality_auto
    completeness - 5 * contamination
  end

  def quality?
    completeness? && contamination?
  end

  def quality_auto?
    completeness_auto? && contamination_auto?
  end

  %i[
    gc_content completeness contamination most_complete_16s number_of_16s
    most_complete_23s number_of_23s number_of_trnas quality
  ].each do |i|
    define_method(:"#{i}_any") do
      send(:"#{i}_auto") || send(i)
    end
    define_method(:"#{i}_any?") do
      send(:"#{i}_auto?") || send(:"#{i}?")
    end
  end

  def complete?
    required = %i[
      kind? seq_depth source_database? source_accession?
      completeness_any contamination_any most_complete_16s_any
      number_of_16s_any number_of_trnas_any
    ]
    required.all? { |i| send(i) }
  end
end
