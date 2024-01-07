module Name::ExternalResources
  ##
  # By default, external requests are deferred to a later time (async).
  # If set to +true+, external requests are performed on demand
  attr_accessor :make_external_requests

  ##
  # The class of an asynchronous job for external resources, required by
  # the +HasExternalResources+ interface
  def external_resources_job
    NameExternalResourcesJob
  end

  ##
  # Execute a programmatic search of the current name in the external +service+
  def external_search(service)
    unless make_external_requests
      queue_for_external_resources
      return
    end

    uri = send("#{service}_search_uri")
    body = external_request(uri)

    if body.present?
      send("#{service}_json=", body)
      send("#{service}_at=", Time.now)
    end
  end

  ##
  # Retrieve the cached response in JSON for the external +service+
  def external_json(service)
    send("#{service}_json")
  end

  ##
  # Indicate when the +service+ was last successfully queried
  def external_at(service)
    send("#{service}_at")
  end

  ##
  # Parse the cached JSON response as a hash, retrieving it if missing and
  # renewing it if too old (over 2 months ago)
  def external_hash(service)
    @external_hash ||= {}
    @external_hash[service] ||= nil
    return @external_hash[service] unless @external_hash[service].nil?

    # If the cached JSON is missing or old, retrieve anew
    if !external_json(service) || external_at(service) < 2.months.ago
      external_search(service)
    end

    # Return parsed cached response or nil
    if external_json(service)
      update_column(:queued_external, nil) if queued_for_external_resources
      @external_hash[service] = JSON.parse(
        external_json(service), symbolize_names: true
      )
    else
      nil
    end
  end

  def itis_search_uri
    base = 'https://www.itis.gov/ITISWebService/jsonservice'
    "#{base}/searchByScientificNameExact?srchKey=#{base_name}"
  end

  def itis_hash
    external_hash(:itis)
  end

  def itis_homonyms
    return [] unless itis_hash

    base = 'https://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&'
    names = itis_hash[:scientificNames].compact || []
    names.map do |i|
      "<a href=\"#{base}&search_value=#{i[:tsn]}\" target=_blank>" \
        "<i>#{i[:combinedName]}</i> #{i[:author]} (<i>#{i[:kingdom]}</i>)" \
        "</a>"
    end
  end

  def gbif_search_uri
    base = 'https://api.gbif.org/v1'
    "#{base}/species?name=#{base_name}"
  end

  def gbif_hash
    external_hash(:gbif)
  end

  def gbif_homonyms(prefix = false, all = false)
    return [] unless gbif_hash

    base = 'https://www.gbif.org/species'
    names = gbif_hash[:results] || []
    names.map do |i|
      next if !all && !i[:nomenclaturalStatus].include?('VALIDLY_PUBLISHED')

      kingdom = i[:kingdom] ? "(<i>#{i[:kingdom]}</i>)" : ''
      name = i[:authorship].present? ? i[:canonicalName] : i[:scientificName]
      name ||= i[:scientificName] || i[:canonicalName]

      "<a href=\"#{base}/#{i[:key]}\" target=_blank>" \
        "#{'GBIF: ' if prefix}<i>#{name}</i> #{i[:authorship]} #{kingdom}</a>"
    end.compact
  end

  def irmng_search_uri
    base = 'https://www.irmng.org/rest/AphiaRecordsByNames'
    "#{base}?scientificnames[]=#{base_name}&like=false"
  end

  def irmng_hash
    external_hash(:irmng)
  end

  def irmng_homonyms(prefix = false)
    return [] unless irmng_hash && !irmng_hash.empty?

    (irmng_hash.first || []).map do |i|
      "<a href=\"#{i[:url]}\" target=_blank>" \
        "#{'IRMNG: ' if prefix}" \
        "<i>#{i[:scientificname]}</i> #{i[:authority]} " \
        "(<i>#{i[:kingdom]}</i>)</a>"
    end
  end

  def col_search_uri
    base = 'https://api.catalogueoflife.org/name/matching'
    "#{base}?q=#{base_name}&verbose=true"
  end

  def col_hash
    external_hash(:col)
  end

  def col_homonyms
    return [] unless col_hash && col_hash[:type] == 'exact'

    (col_hash[:alternatives] || []).map do |i|
      "#{i[:labelHtml]} " \
        "(<a href=\"https://www.catalogueoflife.org/\" target=_blank>COL</a>)"
    end
  end

  def external_homonyms
    # Try IRMNG, which is the fastest and best formatted option
    return irmng_homonyms unless irmng_homonyms.empty?

    # Next, try ITIS, which is slower but very conveniently formatted
    return itis_homonyms unless itis_homonyms.empty?

    # Next, try GBIF, which is fast and well formatted, but includes many
    # questionable sources
    return gbif_homonyms unless gbif_homonyms.empty?

    # Finally, try COL, which is the least convenient but most comprehensive
    ### Excluding COL for now, since it generates too many false positives
    ### that cannot be filtered due to the lack of additional information
    ### return col_homonyms unless col_homonyms.empty?

    []
  end

end
