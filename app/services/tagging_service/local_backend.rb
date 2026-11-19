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
#     local_max_tokens: 1024             # output tokens per name (default
#                                        # 1024; raise for reasoning models)
#     local_temperature: 0               # sampling temperature (default 0,
#                                        # i.e., greedy and deterministic)
#
# bypass_external_apis does not apply: the server is expected to be under
# our control (on this host or reached through an SSH tunnel), and requests
# carry only public data (the prompt and the etymology of each name). This
# is not enforced, though: names are sent to whatever local_url points to,
# so it should only point to servers we trust.
class TaggingService::LocalBackend
  include TaggingService::Prompt
  include TaggingService::HttpBackend

  DEFAULT_URL = 'http://127.0.0.1:8080'.freeze
  DEFAULT_TIMEOUT = 300
  DEFAULT_MAX_TOKENS = 1024
  DEFAULT_TEMPERATURE = 0

  # Identifier of the model loaded by the server, for evaluation reports
  # (see server_model)
  def self.model_label
    new.server_model
  end

  def propose(name)
    etym = etymology_text(name)
    raise TaggingService::Error, "No etymology for #{name.name}" if etym.blank?

    response = call_api(build_messages(name, etym))
    TaggingService.record_usage(usage(response))
    parse_response(response)
  end

  # Identifier of the model loaded by the server, or 'unknown' if the
  # server doesn't report one. Without --alias, llama-server reports the
  # model path, so only its file name is kept (as it's stored in the notes
  # of the proposals). Raises TaggingService::Error if the settings are
  # invalid or the server can't be reached, so callers can stop before
  # sending any names
  def server_model
    check_settings
    body = request(Net::HTTP::Get.new(endpoint('/v1/models')), 10)
    data = body['data'] if body.is_a?(Hash)
    model = data.first if data.is_a?(Array)
    id = model['id'].to_s if model.is_a?(Hash)
    File.basename(id.to_s).presence || 'unknown'
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
    req.body = JSON.generate(
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature,
      response_format: {
        type: 'json_schema',
        json_schema: { name: 'tags', strict: true, schema: response_schema }
      }
    )
    request(req, timeout)
  end

  # Send +req+ with the API key, if any (see HttpBackend#send_request)
  def request(req, read_timeout)
    req['Authorization'] = "Bearer #{api_key}" if api_key.present?
    send_request(req, endpoint('/'), read_timeout)
  end

  def service_name
    'Local model'
  end

  # As servers may ignore response_format, the choice is checked for shape
  # too (see HttpBackend#parse_proposals)
  def parse_response(body)
    choice = Array(body['choices']).first if body.is_a?(Hash)
    unless choice.is_a?(Hash)
      raise TaggingService::Error, 'Local model returned no choices'
    end
    raise_truncated if choice['finish_reason'] == 'length'

    parse_proposals(choice.dig('message', 'content'))
  end

  # OpenAI-style usage mapped to TaggingService::USAGE_FIELDS: prompt_tokens
  # includes the tokens served from the prompt cache. Only recent builds of
  # llama-server report prompt_tokens_details.cached_tokens; older ones
  # count every prompt token as input, even when the cache was used.
  # Returns nil if the response has no usage (or isn't an object; see
  # parse_response)
  def usage(body)
    usage = body['usage'] if body.is_a?(Hash)
    return unless usage.is_a?(Hash)

    details = usage['prompt_tokens_details']
    cached = details.is_a?(Hash) ? details['cached_tokens'].to_i : 0
    {
      'input_tokens' => usage['prompt_tokens'].to_i - cached,
      'cache_creation_input_tokens' => 0,
      'cache_read_input_tokens' => cached,
      'output_tokens' => usage['completion_tokens'].to_i
    }
  end

  # +path+ relative to the configured URL, keeping any path prefix it has
  # (e.g. http://host/llama for a server behind a reverse proxy)
  def endpoint(path)
    URI.join(base_url.chomp('/') + '/', path.delete_prefix('/'))
  end

  # The configured URL, if it's an http(s) URL with a host. Raises
  # TaggingService::Error otherwise (e.g. "localhost:8080", missing the
  # scheme), before any request is sent
  def base_url
    url = setting(:local_url).presence || DEFAULT_URL
    uri = URI.parse(url)
    return url if uri.is_a?(URI::HTTP) && uri.host.present?

    raise URI::InvalidURIError
  rescue URI::InvalidURIError
    raise(
      TaggingService::Error,
      "Invalid local_url: #{url} (expected e.g. #{DEFAULT_URL})"
    )
  end

  def api_key
    setting(:local_api_key)
  end

  def timeout
    number_setting(:local_timeout, DEFAULT_TIMEOUT, :positive_integer)
  end

  def max_tokens
    number_setting(:local_max_tokens, DEFAULT_MAX_TOKENS, :positive_integer)
  end

  def temperature
    number_setting(:local_temperature, DEFAULT_TEMPERATURE, :non_negative)
  end

  # Raise TaggingService::Error if any setting is invalid, so callers can
  # stop before sending any names (see server_model)
  def check_settings
    base_url
    timeout
    max_tokens
    temperature
  end

  # The setting +key+ (or +default+ if unset) as a number of +kind+: a
  # :positive_integer, or a :non_negative Float. Raises TaggingService::Error
  # otherwise, as a 0 from a typo would make every request fail (e.g. a read
  # timeout of 0 seconds or max_tokens of 0)
  def number_setting(key, default, kind)
    value = setting(key)
    value = default if value.blank?
    number =
      if kind == :positive_integer
        Integer(value.to_s, 10, exception: false) # Not octal for '010'
      else
        Float(value.to_s, exception: false)
      end
    valid = kind == :positive_integer ? number&.positive? : number&.>=(0)
    return number if valid

    expected =
      kind == :positive_integer ? 'a positive integer' : 'a number >= 0'
    raise(
      TaggingService::Error,
      "Invalid #{key}: #{value.inspect} (expected #{expected})"
    )
  end

  def setting(key)
    Rails.application.credentials.dig(:tagging, key)
  end
end
