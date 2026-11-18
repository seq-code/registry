require 'net/http'
require 'json'

# Tagging backend for a self-hosted model served by llama.cpp's llama-server
# (or any server with an OpenAI-compatible chat completions endpoint that
# accepts a JSON schema as response_format). It sends the same prompt and
# schema as AnthropicBackend (see TaggingService::Prompt).
#
# Configured in credentials, all optional:
#   tagging:
#     backend: local
#     local_url: http://127.0.0.1:8080   # default
#     local_api_key: ...                 # if the server uses --api-key
#     local_timeout: 300                 # seconds per name (default 300)
#
# The server is expected to be under our control (on this host or reached
# through an SSH tunnel), so data sent to it doesn't leave our
# infrastructure. For that reason, bypass_external_apis does not apply.
class TaggingService::LocalBackend
  include TaggingService::Prompt

  DEFAULT_URL = 'http://127.0.0.1:8080'.freeze
  DEFAULT_TIMEOUT = 300
  MAX_TOKENS = 1024

  # Identifier of the model loaded by the server, for evaluation reports,
  # or 'unknown' if the server can't be reached
  def self.model_label
    new.send(:server_model) || 'unknown'
  end

  def propose(name)
    etym = etymology_text(name)
    raise TaggingService::Error, "No etymology for #{name.name}" if etym.blank?

    response = call_api(build_messages(name, etym))
    TaggingService.record_usage(usage(response))
    parse_response(response)
  end

  private

  # The system prompt is static and comes first, so llama-server can reuse
  # its cached prefix across names (cache_prompt is on by default)
  def build_messages(name, etym)
    [
      { role: 'system', content: system_prompt },
      { role: 'user', content: name_prompt(name, etym) }
    ]
  end

  def call_api(messages)
    req = Net::HTTP::Post.new(endpoint('/v1/chat/completions'))
    req['Content-Type'] = 'application/json'
    req['Authorization'] = "Bearer #{api_key}" if api_key.present?
    req.body = JSON.generate(
      messages: messages,
      max_tokens: MAX_TOKENS,
      temperature: 0,
      response_format: {
        type: 'json_schema',
        json_schema: { name: 'tags', strict: true, schema: response_schema }
      }
    )
    JSON.parse(http(timeout).request(req).tap { |res| check!(res) }.body)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise TaggingService::Error, "Local model timeout: #{e.message}"
  rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => e
    raise TaggingService::Error, "Local model connection error: #{e.message}"
  rescue JSON::ParserError => e
    raise TaggingService::Error, "Local model invalid JSON: #{e.message}"
  end

  def check!(response)
    return if response.is_a?(Net::HTTPSuccess)

    raise(
      TaggingService::Error,
      "Local model error #{response.code}: #{response.body.to_s.truncate(200)}"
    )
  end

  def parse_response(body)
    choice = Array(body['choices']).first or
      raise(TaggingService::Error, 'Local model returned no choices')
    if choice['finish_reason'] == 'length'
      raise TaggingService::Error, 'Model response truncated (max_tokens)'
    end

    text = choice.dig('message', 'content').to_s
    filter_proposals(JSON.parse(text)['tags'] || [])
  rescue JSON::ParserError => e
    raise(
      TaggingService::Error,
      "Could not parse model response: #{e.message} — #{text.truncate(200)}"
    )
  end

  # OpenAI-style usage mapped to TaggingService::USAGE_FIELDS: prompt_tokens
  # includes the tokens served from the prompt cache
  def usage(body)
    usage = body['usage'] or return
    cached = usage.dig('prompt_tokens_details', 'cached_tokens').to_i
    {
      'input_tokens' => usage['prompt_tokens'].to_i - cached,
      'cache_creation_input_tokens' => 0,
      'cache_read_input_tokens' => cached,
      'output_tokens' => usage['completion_tokens'].to_i
    }
  end

  def server_model
    req = Net::HTTP::Get.new(endpoint('/v1/models'))
    req['Authorization'] = "Bearer #{api_key}" if api_key.present?
    res = http(10).request(req)
    return unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body).dig('data', 0, 'id')
  rescue StandardError
    nil
  end

  def http(read_timeout)
    uri = endpoint('/')
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = read_timeout
    end
  end

  # +path+ relative to the configured URL, keeping any path prefix it has
  # (e.g. http://host/llama for a server behind a reverse proxy)
  def endpoint(path)
    base = (setting(:local_url).presence || DEFAULT_URL).chomp('/') + '/'
    URI.join(base, path.delete_prefix('/'))
  end

  def api_key
    setting(:local_api_key)
  end

  def timeout
    (setting(:local_timeout).presence || DEFAULT_TIMEOUT).to_i
  end

  def setting(key)
    Rails.application.credentials.dig(:tagging, key)
  end
end
