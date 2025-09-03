module Strain::ExternalResources
  ##
  # The class of an asynchronous job for external resources, required by
  # the +HasExternalResources+ interface
  def external_resources_job
    StrainExternalResourcesJob
  end

  ##
  # Returns the StrainInfo parsed Hash using the stored +strain_info_json+
  # entry. If the stored JSON entry is unavailable, it requests data to the
  # StrainInfo API and awaits the response before returning. If the retrieved
  # data is older than 6 months, it triggers a background job to retrieve the
  # data via StrainInfo API, but returns whatever is currently stored. If
  # +reload+ is +false+ it doesn't wait for reloads, but it might still trigger
  # background jobs.
  def strain_info_hash(reload = true)
    @strain_info_hash ||=
      JSON.parse(strain_info_json || 'null', symbolize_names: true)

    if !@strain_info_hash.present?
      return unless reload

      reload_strain_info_json!
      strain_info_hash(false)
    end

    if @strain_info_hash[:retrieved_at] < 6.months.ago
      queue_for_external_resources
    end

    @strain_info_hash
  end

  ##
  # Returns only the data from StrainInfo, see +strain_info_hash+ for details
  def strain_info_data(reload = true)
    (strain_info_hash(reload) || {})[:data]
  end

  ##
  # Execute a programmatic search of the strain number(s)
  def reload_strain_info_json!
    reload # To make sure I use the current persistent version
    str_ids = external_strain_info_ids(numbers)
    data = external_strain_info_data(str_ids)
    self.strain_info_json = { retrieved_at: DateTime.now, data: data }.to_json
    self.queued_external = nil
    save
  end

  ##
  # Find StrainInfo IDs from strain numbers and return as parsed Array of
  # Integers
  def external_strain_info_ids(numbers)
    external_strain_info_api(
      'search/strain/str_no',
      numbers.map { |i| i.gsub(',', ' ') }
    )
  end

  ##
  # Retrieve StrainInfo data from strain IDs and return as parsed Array of
  # Hashes
  def external_strain_info_data(ids)
    external_strain_info_api('data/strain/avg', ids)
  end

  ##
  # Generic entrypoint for StrainInfo API
  def external_strain_info_api(action, acc, empty = [])
    return empty unless acc.present?

    require 'uri'
    str_acc = URI.encode_www_form_component(acc.join(',')).gsub('+', '%20')
    uri = 'https://api.straininfo.dsmz.de/v1/%s/%s' % [action, str_acc]
    body = external_request(uri)
    return empty unless body.present?

    # Pre-processing to avoid a strange StrainInfo bug returning malformed JSON
    body.gsub!(/,,+/, ',')
    body.gsub!(/^\[,/, '[')
    body.gsub!(/,\]$/, ']')
    JSON.parse(body)
  end
end
