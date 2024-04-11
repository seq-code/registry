module HasExternalResources
  ##
  # Is the currently loaded name queued for +NameExternalResourcesJob+ and has
  # it been queued for less than a day?
  def queued_for_external_resources
    queued_external && queued_external > 1.day.ago
  end

  ##
  # Queue name for +NameExternalResourcesJob+
  def queue_for_external_resources
    return if Rails.configuration.bypass_external_apis
    return if queued_for_external_resources

    external_resources_job.perform_later(self)
    update_column(:queued_external, DateTime.now)
  end

  ##
  # Generate a request to the external +uri+, and return the reponse body
  # if successful or +nil+ otherwise (fails silently)
  def external_request(uri)
    return if Rails.configuration.bypass_external_apis

    require 'uri'
    require 'net/http'

    res = Net::HTTP.get_response(URI(uri))
    unless res.is_a?(Net::HTTPSuccess)
      Rails.logger.error "External Request #{uri} returned #{res}"
      return nil
    end
    res.body ? normalize_encoding(res.body) : nil
  rescue
    nil
  end

  def normalize_encoding(body)
    # Test encodings
    body.force_encoding('utf-8')
    %w[iso8859-1 windows-1252 us-ascii ascii-8bit].each do |enc|
      break if body.valid_encoding?
      recode = body.force_encoding(enc).encode('utf-8')
      body = recode if recode.valid_encoding?
    end

    # If nothing works, replace offending characters with '?'
    unless body.valid_encoding?
      body = body.encode(
        'utf-8', invalid: :replace, undef: :replace, replace: '?'
      )
    end

    body
  end
end
