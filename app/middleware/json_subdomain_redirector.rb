require 'uri'

##
# Make sure that the API calls are channeled through the API domain and the
# GUI calls are channeled through the GUI domain
class JsonSubdomainRedirector
  def initialize(app)
    @gui_domain = 'registry.seqco.de'
    @api_domain = 'api.seqco.de'
    @api_version = 'v1'
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    if on_api_subdomain?(request)
      redirect_to_gui(request) unless is_api_call?(request)
    else
      redirect_to_api(request) if is_api_call?(request)
    end
  end

  def redirect_to_api(request)
    is_versioned = request.path.match?(/^\/v\d+\//)
    new_path = is_versioned ? request.path : "/#{@api_version}#{request.path}"

    # Reconstruct URL
    uri = URI.parse(request.url)
    uri.host = @api_domain
    uri.path = new_path

    return [
      301,
      { 'Location' => uri.to_s, 'Content-Type' => 'text/html' },
      ['Moved Permanently']
    ]
  end

  def redirect_to_gui(request)
    new_path = request.path.gsub(/^\/v\d+\//, '/')

    # Reconstruct URL
    uri = URI.parse(request.url)
    uri.host = @gui_domain
    uri.path = new_path

    return [
      301,
      { 'Location' => uri.to_s, 'Content-Type' => 'text/html' },
      ['Moved Permanently']
    ]
  end

  def is_json?(request)
    request.get_header('HTTP_ACCEPT')&.include?('application/json') ||
      request.path.end_with?('.json')
  end

  def is_core_json?(request)
    path = request.path
    path.end_with?('autocomplete.json') ||
      path.end_with?('network.json') ||
      path.match?(/check\/\d+\.json$/)
  end

  def is_api_call?(request)
    is_json?(request) && !is_core_json?(request)
  end

  def on_api_subdomain?(request)
    request.host == @api_domain
  end
end
