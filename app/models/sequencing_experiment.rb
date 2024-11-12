class SequencingExperiment < ApplicationRecord
  has_many(:genome_sequencing_experiments, dependent: :destroy)
  has_many(:genomes, through: :genome_sequencing_experiments)

  validates(:sra_accession, presence: true, uniqueness: true)
  before_validation(:load_from_sra_accession)

  include HasExternalResources
  include SequencingExperiment::ExternalResources

  class << self
    def by_biosample(acc)
      SequencingExperiment.where(biosample_accession: acc)
    end

    def by_sra(acc)
      SequencingExperiment.find_or_create_by(sra_accession: acc)
    end
  end

  def link
    return unless sra_accession.present?

    "https://www.ncbi.nlm.nih.gov/sra/#{sra_accession}[accn]"
  end

  def metadata_dom
    return unless metadata_xml
    @metadata_dom ||= Nokogiri::XML(metadata_xml)
  end

  def metadata_xpath(path)
    metadata_dom&.xpath(path)
  end

  def title
    metadata_xpath('//EXPERIMENT_SET/EXPERIMENT/TITLE')&.text || sra_acccession
  end

  def bioproject_accession
    @bioproject_accession ||= nil
    return @bioproject_accession unless @bioproject_accession.nil?

    study = metadata_xpath('//EXPERIMENT_SET/EXPERIMENT/STUDY_REF')&.first
    @bioproject_accession ||=
      study&.xpath(
        'IDENTIFIERS/EXTERNAL_ID[@namespace="BioProject"]'
      )&.first&.text || ''
  end

  def bioproject_link
    return unless bioproject_accession.present?

    "https://www.ncbi.nlm.nih.gov/bioproject/#{bioproject_accession}"
  end

  private

  def load_from_sra_accession
    reload_metadata! if sra_accession_changed? || !metadata_xml.present?
  end
end
