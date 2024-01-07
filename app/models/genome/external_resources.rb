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
    sleep(5) # To avoid racing against a recent DB save
    data = {}
    case source_database.to_sym
    when :sra
      source_accession.split(/, */).each do |acc|
        external_sra_to_biosamples(acc).each do |biosample|
          data[biosample] ||=
            {from_sra: []}.merge(external_biosample_hash(biosample))
          data[biosample][:from_sra] << acc
        end
      end
    when :biosample
      source_accession.split(/, */).each do |acc|
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
    uri = "https://www.ebi.ac.uk/ena/browser/api/xml/#{acc}?includeLinks=false"
    body = external_request(uri)
    return {} unless body && body != '{}'

    ng = Nokogiri::XML(body)
    {}.tap do |hash|
      hash[:title] = ng.xpath('//SAMPLE_SET/SAMPLE/TITLE').text
      hash[:description] = ng.xpath('//SAMPLE_SET/SAMPLE/DESCRIPTION').text
      hash[:attributes] = Hash[
        ng.xpath('//SAMPLE_SET/SAMPLE/SAMPLE_ATTRIBUTES/SAMPLE_ATTRIBUTE')
          .map { |attr| [attr.xpath('TAG').text, attr.xpath('VALUE').text] }
      ]
    end
  end

end
