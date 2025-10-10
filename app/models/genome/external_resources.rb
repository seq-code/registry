module Genome::ExternalResources
  ##
  # The class of an asynchronous job for external resources, required by
  # the +HasExternalResources+ interface
  def external_resources_job
    GenomeExternalResourcesJob
  end

  ##
  # Source hash using the stored +source_json+ entry
  def source_hash
    return unless source_json

    @source_hash ||= JSON.parse(source_json, symbolize_names: true)
  end

  ##
  # Execute a programmatic search of the genome sample(s)
  def reload_source_json!
    reload # To make sure I use the current persistent version
    ephemeral_report << 'Reloading sources'
    data = {}
    case source_database.to_sym
    when :sra
      source_accessions.each do |acc|
        ephemeral_resouce << "SRA:#{acc}"
        biosample = external_sra_to_biosample(acc)
        ephemeral_resource << "Linked to BioSample#{biosample}"
        data[biosample] ||=
          { from_sra: [] }.merge(external_biosample_hash(biosample))
        data[biosample][:from_sra] << acc
      end
    when :biosample
      source_accessions.each do |acc|
        ephemeral_resouce << "BioSample:#{acc}"
        data[acc] = external_biosample_hash(acc)
        data[acc][:biosample_accessions].each do |acc_alt|
          external_biosample_to_sra(acc_alt)
        end
      end
    end

    self.source_json = { retrieved_at: DateTime.now, samples: data }.to_json
    self.queued_external = nil
    save
  end

  ##
  # Find BioSample accession linked to the SRA entry +acc+ and return as
  # String (or +nil+)
  def external_sra_to_biosample(acc)
    SequencingExperiment.by_sra(acc).try(:biosample_accession)
  end

  ##
  # Find SRA entries linked to the BioSample +acc+ and return as Array
  def external_biosample_to_sra(acc)
    uri = "https://www.ebi.ac.uk/ebisearch/ws/rest/sra-experiment?" +
          "query=BIOSAMPLE:#{acc}"
    body = external_request(uri)
    return unless body.present?

    ng = Nokogiri::XML(body)
    ng.xpath('//result/entries/entry').map do |exp|
      sra_acc = exp['acc'] || exp['id'] or next
      SequencingExperiment.find_or_create_by(sra_accession: sra_acc)
    end
  end

  ##
  # Retrieve BioSample metadata and return as a parsed Hash
  def external_biosample_hash(acc)
    y = external_biosample_hash_ebi(acc)
    y = external_biosample_hash_ncbi(acc) unless y.present?
    y = { biosample_accessions: [acc] } unless y.present?
    y
  end

  ##
  # Retrieve BioSample metadata and return as a parsed Hash from EBI
  def external_biosample_hash_ebi(acc)
    uri = "https://www.ebi.ac.uk/ena/browser/api/xml/#{acc}?includeLinks=false"
    body = external_request(uri)
    return unless body.present?

    ng = Nokogiri::XML(body)
    sample = ng.xpath('//SAMPLE_SET/SAMPLE').first or return
    {}.tap do |hash|
      h = { api: 'EBI' }
      h[:title] = sample.xpath('./TITLE').text
      h[:description] = sample.xpath('./DESCRIPTION').text
      h[:attributes] = Hash[
        sample.xpath('./SAMPLE_ATTRIBUTES/SAMPLE_ATTRIBUTE')
          .map { |attr| [attr.xpath('TAG').text, attr.xpath('VALUE').text] }
      ]
      h[:biosample_accessions] = [
        acc, sample['accession'],
        sample.xpath('./IDENTIFIERS/PRIMARY_ID').text,
        sample.xpath('./IDENTIFIERS/SECONDARY_ID').text,
        sample.xpath('./EXTERNAL_ID[@namespace="BioSample"]').text
      ].select(&:present?).uniq
      h.each { |k, v| hash[k] = h[k] if h[k].present? }
    end
  end

  ##
  # Retrieve BioSample metadata and return as a parsed Hash from NCBI
  def external_biosample_hash_ncbi(acc)
    uri = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?' \
          "db=biosample&id=#{acc}&rettype=xml&retmode=text"
    body = external_request(uri)
    return unless body.present?

    ng = Nokogiri::XML(body)
    sample = ng.xpath('//BioSampleSet/BioSample').first or return
    {}.tap do |hash|
      h = { api: 'NCBI' }
      h[:title] = sample.xpath('./Description/Title').text
      h[:description] = sample.xpath('./Description/Comment/Paragraph').text
      h[:attributes] = Hash[
        sample.xpath('./Attributes/Attribute')
          .map do |attr|
            [attr['harmonized_name'] || attr['attribute_name'], attr.text]
          end
      ]
      package = sample.xpath('./Package').text
      h[:attributes][:ncbi_package] = package if package.present?
      h[:biosample_accessions] = [
        acc, sample['accession'],
        sample.xpath('./Ids/Id[@db="BioSample"]').text,
        sample.xpath('./Ids/Id[@db="SRA"]').text
      ].compact.uniq
      h.each { |k, v| hash[k] = h[k] if h[k].present? }
    end
  end
end
