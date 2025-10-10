module HasExternalResources
  ##
  # Is the currently loaded name queued for +NameExternalResourcesJob+ and has
  # it been queued for less than a day?
  def queued_for_external_resources
    queued_external && queued_external > 1.day.ago
  end

  ##
  # Queue name for +NameExternalResourcesJob+, possibly forcing queue even if
  # it was recently submitted (+force+)
  def queue_for_external_resources(force = false)
    return if Rails.configuration.bypass_external_apis
    return if !force && queued_for_external_resources

    ephemeral_report << 'Queued for external resource call'
    external_resources_job.perform_later(self)
    update_column(:queued_external, DateTime.now)
  end

  ##
  # Forget about interrupted updates
  def force_reset_external_resources
    update_column(:queued_external, nil)
  end

  ##
  # Generate a request to the external +uri+, and return the reponse body
  # if successful or +nil+ otherwise (fails silently). If the return code
  # is 204 (empty contents), returns +empty+
  def external_request(uri, empty = nil)
    return if Rails.configuration.bypass_external_apis

    require 'uri'
    require 'net/http'

    ephemeral_report << "Request: #{uri}"
    res = Net::HTTP.get_response(URI(uri))
    unless res.is_a?(Net::HTTPSuccess)
      msg = "External Request #{uri} returned #{res}"
      Rails.logger.error(msg)
      ephemeral_report.error(msg)
      return nil
    end

    res.is_a?(Net::HTTPNoContent) ? empty :
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

  def ephemeral_report
    @ephemeral_report ||= EphemeralReport.new
  end
end
