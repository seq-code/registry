module HasExternalResources
  ##
  # Is the currently loaded name queued for +NameExternalResourcesJob+ and has
  # it been queued for less than a day?
  def queued_for_external_resources
    queued_external && queued_external > 1.day.ago
  end

  ##
  # Queue name for +NameExternalResourcesJob+, possibly forcing queue even if
  # it was recently submitted (+force+). If +sync+ is +true+, the job is
  # executed immediately (in-process) instead of enqueued for later, since
  # this application has no persistent job backend: an enqueued job only
  # runs if this same process happens to still be alive when it's picked up,
  # and is otherwise silently lost (e.g. across a deploy).
  # TODO: This should be revisited when Rails is upgraded to 7.1, which will
  # support ActiveJob with a persistent backend.
  def queue_for_external_resources(force = false, sync: false)
    return if Rails.configuration.bypass_external_apis
    return if !force && queued_for_external_resources

    ephemeral_report << (
      sync ? 'Requesting external resources' : 'Queued for external resource call'
    )
    queued = update_column(:queued_external, DateTime.now)
    sync ? external_resources_job.perform_now(self) : external_resources_job.perform_later(self)
    queued
  end

  ##
  # Forget about interrupted updates
  def force_reset_external_resources
    update_column(:queued_external, nil)
  end

  # Identifies the Registry in external requests, as required by some services
  # (e.g., Wikimedia, which throttles generic user agents more aggressively)
  EXTERNAL_USER_AGENT =
    'SeqCodeRegistry/1.0 (https://registry.seqco.de; seqcode@bio.aau.dk)'

  ##
  # Generate a request to the external +uri+, and return the response, or
  # +nil+ if the request couldn't be completed (fails silently)
  def external_response(uri)
    return if Rails.configuration.bypass_external_apis

    require 'uri'
    require 'net/http'

    ephemeral_report << "Request: #{uri}"
    res = Net::HTTP.get_response(
      URI(uri), 'User-Agent' => EXTERNAL_USER_AGENT
    )
    unless res.is_a?(Net::HTTPSuccess)
      msg = "External Request #{uri} returned #{res}"
      Rails.logger.error(msg)
      ephemeral_report.error(msg)
    end
    res
  rescue
    nil
  end

  ##
  # Generate a request to the external +uri+, and return the reponse body
  # if successful or +nil+ otherwise (fails silently). If the return code
  # is 204 (empty contents), returns +empty+
  def external_request(uri, empty = nil)
    res = external_response(uri)
    return nil unless res.is_a?(Net::HTTPSuccess)

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
    @ephemeral_report ||= EphemeralReport.new(self)
  end
end
