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
        external_sra_to_biosamples(acc).each do |biosample|
          data[biosample] ||=
            { from_sra: [] }.merge(external_biosample_hash(biosample))
          data[biosample][:from_sra] << acc
        end
      end
    when :biosample
      source_accessions.each do |acc|
        data[acc] = external_biosample_hash(acc)
      end
    end

    update_column(:queued_external, nil)
    update_column(
      :source_json, { retrieved_at: DateTime.now, samples: data }.to_json
    )
  end

  ##
  # Find all BioSample accessions linked to the SRA entry +acc+ and return as
  # Array (typically one value)
  def external_sra_to_biosamples(acc)
    uri = "https://www.ebi.ac.uk/ena/browser/api/xml/#{acc}?includeLinks=false"
    body = external_request(uri)
    return [] unless body && body != '{}'

    ng = Nokogiri::XML(body)
    if ng.xpath('//RUN_SET').present?
      ng.xpath(
        '//RUN_SET/RUN/RUN_LINKS/RUN_LINK/' \
          'XREF_LINK[DB[text() = "ENA-SAMPLE"]]/ID'
      ).map(&:text)
    elsif ng.xpath('//EXPERIMENT_SET').present?
      ng.xpath(
        '//EXPERIMENT_SET/EXPERIMENT/DESIGN/SAMPLE_DESCRIPTOR/' \
          'IDENTIFIERS/PRIMARY_ID'
      ).map(&:text)
    else
      [] # Unknown XML specification
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
      h = {}
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
      h = {}
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
