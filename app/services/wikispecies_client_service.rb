class WikispeciesClientService
  class Error < StandardError; end

  TOKEN_URL = 'https://species.wikimedia.org/w/rest.php/oauth2/access_token'
  API_URL   = 'https://species.wikimedia.org/w/api.php'

  def initialize(credential)
    @credential = credential
    refresh_if_expired!
  end

  def create_page(title:, content:, summary:)
    token = csrf_token
    resp = post(
      action: 'edit', title: title, text: content, summary: summary,
      createonly: 1, token: token, format: 'json'
    )
    body = JSON.parse(resp.body)
    raise Error, body.dig('error', 'info') if body['error']

    body
  end

  private

  def refresh_if_expired!
    return unless @credential.expired? && @credential.refresh_token

    creds = Rails.application.credentials.wikimedia
    uri = URI(TOKEN_URL)
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(
      grant_type: 'refresh_token',
      refresh_token: @credential.refresh_token,
      client_id: creds[:client_key],
      client_secret: creds[:client_secret]
    )
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    token = JSON.parse(res.body)
    raise Error, token['error_description'] if token['error']

    @credential.update!(
      access_token: token['access_token'],
      refresh_token: token['refresh_token'] || @credential.refresh_token,
      expires_at: token['expires_in']&.seconds&.from_now
    )
  end

  def csrf_token
    resp = get(action: 'query', meta: 'tokens', format: 'json')
    JSON.parse(resp.body).dig('query', 'tokens', 'csrftoken')
  end

  def get(params)
    request(Net::HTTP::Get, params)
  end

  def post(params)
    req = Net::HTTP::Post.new(URI(API_URL))
    req.set_form_data(params)
    authorize!(req)
    Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: true) { |http| http.request(req) }
  end

  def request(klass, params)
    uri = URI(API_URL)
    uri.query = URI.encode_www_form(params)
    req = klass.new(uri)
    authorize!(req)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
  end

  def authorize!(req)
    req['Authorization'] = "Bearer #{@credential.access_token}"
    req['User-Agent'] = 'SeqCodeRegistry/1.0 (https://registry.seqco.de)'
  end
end
