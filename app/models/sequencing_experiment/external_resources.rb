module SequencingExperiment::ExternalResources
  ##
  # The class of an asynchronous job for external resources, required by
  # the +HasExternalResources+ interface
  def external_resources_job
    GenomeExternalResourcesJob
  end

  ##
  # Source hash using the stored +source_json+ entry
  def metadata_hash
    return unless biosample_accession

    @metadata_hash ||= {
      sra_accession: sra_accession,
      biosample_accession: biosample_accession,
      retrieved_at: retrieved_at
    }
  end

  attr_accessor :external_reuse_metadata_xml

  ##
  # Execute a programmatic search of the sequencing experiment (or run)
  def reload_metadata!
    self.metadata_xml = nil unless external_reuse_metadata_xml
    external_sra_to_biosample!
    self.queued_external = nil
    self.retrieved_at = DateTime.now
  end
  alias :reload_source_json! :reload_metadata!

  ##
  # Find BioSample accession linked to the SRA entry and store in the current
  # instance (but don't save the object!)
  def external_sra_to_biosample!
    acc = sra_accession or return
    uri = "https://www.ebi.ac.uk/ena/browser/api/xml/#{acc}"
    self.metadata_xml ||= external_request(uri)
    return unless metadata_xml.present?

    ng = Nokogiri::XML(metadata_xml)
    if ng.xpath('//RUN_SET').present?
      self.biosample_accession =
        ng.xpath(
          '//RUN_SET/RUN/RUN_LINKS/RUN_LINK/' \
            'XREF_LINK[DB[text() = "ENA-SAMPLE"]]/ID'
        ).first.try(:text)
      self.biosample_accession_2 = nil
    elsif ng.xpath('//EXPERIMENT_SET').present?
      # Unfortunately, we should prefer external IDs over primary IDs because
      # NCBI E-Utils has a strange tendency to return the wrong biosample when
      # using SRS... accessions. For example, see:
      # 
      # - https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?
      #   db=biosample&id=SRS22988103&rettype=xml&retmode=text
      # - https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?
      #   db=biosample&id=SAMN13193749&rettype=xml&retmode=text
      # 
      # The first is using the accession SRS22988103 but it (wrongly)
      # retrieves data for SAMN22988103 (= SRS11001113). Apparently the
      # backend code simply strips off the alphabetic prefix and uses the
      # numeric part without checking
      sample_id =
        ng.xpath(
          '//EXPERIMENT_SET/EXPERIMENT/DESIGN/SAMPLE_DESCRIPTOR/IDENTIFIERS'
        )
      biosample_id =
        sample_id.xpath('//EXTERNAL_ID[@namespace="BioSample"]')
          .first.try(:text)
      if biosample_id.present?
        self.biosample_accession = biosample_id
        self.biosample_accession_2 =
          sample_id.xpath('//PRIMARY_ID').first.try(:text)
      else
        self.biosample_accession =
          sample_id.xpath('//PRIMARY_ID').first.try(:text)
        self.biosample_accession_2 =
          sample_id.xpath('//SECONDARY_ID').first.try(:text)
      end
    else
      # Unknown XML specification
      self.biosample_accession = nil
      self.biosample_accession_2 = nil
    end
  end
end
