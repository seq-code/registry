require 'uri'

class JsonSubdomainRedirector
  def initialize(app)
    @api_domain = 'api.seqco.de'
    @api_version = 'v1'
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    return @app.call(env) if
      !is_json?(request) ||
      is_core_json?(request) ||
      already_on_api_subdomain?(request)

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

  def is_json?(request)
    request.get_header('HTTP_ACCEPT')&.include?('application/json') ||
      request.path.end_with?('.json')
  end

  def is_core_json?(request)
    request.path.end_with?('autocomplete.json') ||
      request.path.end_with?('network.json')
  end

  def already_on_api_subdomain?(request)
    request.host == @api_domain
  end
end
