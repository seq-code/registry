class WikispeciesClientService
  class Error < StandardError; end

  def initialize(access_token:)
    @access_token = access_token
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

  def csrf_token
    resp = get(action: 'query', meta: 'tokens', format: 'json')
    JSON.parse(resp.body).dig('query', 'tokens', 'csrftoken')
  end

  def get(params)
    uri = URI('https://species.wikimedia.org/w/api.php')
    uri.query = URI.encode_www_form(params)
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{@access_token}"
    req['User-Agent'] = 'SeqCodeRegistry/1.0 (https://registry.seqco.de)'
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
  end

  def post(params)
    uri = URI('https://species.wikimedia.org/w/api.php')
    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{@access_token}"
    req['User-Agent'] = 'SeqCodeRegistry/1.0 (https://registry.seqco.de)'
    req.set_form_data(params)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
  end
end
