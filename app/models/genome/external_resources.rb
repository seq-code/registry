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
    data = {}
    case source_database.to_sym
    when :sra
      source_accessions.each do |acc|
        biosample = external_sra_to_biosample(acc)
        data[biosample] ||=
          { from_sra: [] }.merge(external_biosample_hash(biosample))
        data[biosample][:from_sra] << acc
      end
    when :biosample
      source_accessions.each do |acc|
        data[acc] = external_biosample_hash(acc)
        external_biosample_to_sra(acc)
      end
    end

    self.queued_external = nil
    self.source_json = { retrieved_at: DateTime.now, samples: data }.to_json
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
    uri = "https://www.ebi.ac.uk/ena/browser/api/xml/ebisearch?" +
          "query=BIOSAMPLE:#{acc}&includeLinks=true&domain=sra-experiment"
    body = external_request(uri)
    return unless body.present?

    ng = Nokogiri::XML(body)
    ng.xpath('//EXPERIMENT_SET/EXPERIMENT').map do |exp|
      sra_acc = exp['accession'] || exp.xpath('IDENTIFIERS/PRIMARY_ID').text
      SequencingExperiment.find_or_create_by(sra_accession: sra_acc) do |se|
        se.external_reuse_metadata_xml = true
        se.queued_external = nil
        se.retrieved_at = DateTime.now
        se.metadata_xml = "<EXPERIMENT_SET>\n#{exp.to_s}\n</EXPERIMENT_SET>"
      end
    end
  end

  ##
  # Retrieve BioSample metadata and return as a parsed Hash
  def external_biosample_hash(acc)
    y = external_biosample_hash_ebi(acc)
    y = external_biosample_hash_ncbi(acc) unless y.present?
    y = {} unless y.present?
    y
  end

  ##
  # Retrieve BioSample metadata and return as a parsed Hash from EBI
  def external_biosample_hash_ebi(acc)
    uri = "https://www.ebi.ac.uk/ena/browser/api/xml/#{acc}?includeLinks=false"
    body = external_request(uri)
    return unless body && body != '{}'

    ng = Nokogiri::XML(body)
    {}.tap do |hash|
      h = { api: 'EBI' }
      h[:title] = ng.xpath('//SAMPLE_SET/SAMPLE/TITLE').text
      h[:description] = ng.xpath('//SAMPLE_SET/SAMPLE/DESCRIPTION').text
      h[:attributes] = Hash[
        ng.xpath('//SAMPLE_SET/SAMPLE/SAMPLE_ATTRIBUTES/SAMPLE_ATTRIBUTE')
          .map { |attr| [attr.xpath('TAG').text, attr.xpath('VALUE').text] }
      ]
      h.each { |k, v| hash[k] = h[k] if h[k].present? }
    end
  end

  ##
  # Retrieve BioSample metadata and return as a parsed Hash from NCBI
  def external_biosample_hash_ncbi(acc)
    uri = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?' \
          "db=biosample&id=#{acc}&rettype=xml&retmode=text"
    body = external_request(uri)
    return unless body && body != '{}'

    ng = Nokogiri::XML(body)
    {}.tap do |hash|
      h = { api: 'NCBI' }
      h[:title] = ng.xpath('//BioSampleSet/BioSample/Description/Title').text
      h[:description] =
        ng.xpath('//BioSampleSet/BioSample/Description/Comment/Paragraph').text
      h[:attributes] = Hash[
        ng.xpath('//BioSampleSet/BioSample/Attributes/Attribute')
          .map do |attr|
            [attr['harmonized_name'] || attr['attribute_name'], attr.text]
          end
      ]
      package = ng.xpath('//BioSampleSet/BioSample/Package').text
      h[:attributes][:ncbi_package] = package if package.present?
      h.each { |k, v| hash[k] = h[k] if h[k].present? }
    end
  end
end
