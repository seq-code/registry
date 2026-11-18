require 'net/http'
require 'json'

class TaggingService::AnthropicBackend
  include TaggingService::Prompt

  API_URI = URI('https://api.anthropic.com/v1/messages').freeze
  MODEL   = 'claude-sonnet-5-5'
  MAX_TOKENS = 1024

  # Model identifier, for evaluation reports
  def self.model_label
    MODEL
  end

  def propose(name)
    etym = etymology_text(name)
    raise TaggingService::Error, "No etymology for #{name.name}" if etym.blank?

    response = call_api(build_messages(name, etym))
    TaggingService.record_usage(response['usage'])
    parse_response(response)
  end

  # The static part of the prompt, as a system block marked for caching.
  # It must not depend on the name (or anything else that varies between
  # requests), so the cached prefix is reused across names
  def system_blocks
    [
      { type: 'text', text: system_prompt,
        cache_control: { type: 'ephemeral' } }
    ]
  end

  private

  def build_messages(name, etym)
    [{ role: 'user', content: name_prompt(name, etym) }]
  end

  def call_api(messages)
    if Rails.configuration.bypass_external_apis
      raise(
        TaggingService::Error,
        'External APIs are disabled (set ALLOW_EXTERNAL_APIS=1 in development)'
      )
    end

    req = Net::HTTP::Post.new(API_URI)
    req['Content-Type']      = 'application/json'
    req['x-api-key']         = api_key
    req['anthropic-version'] = '2023-06-01'
    workspace_id = Rails.application.credentials.dig(:anthropic, :workspace_id)
    req['anthropic-workspace-id'] = workspace_id if workspace_id.present?
    req.body = JSON.generate(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      # temperature: 0, <- Not compatible with Sonnet 5.5
      system: system_blocks,
      messages: messages,
      output_config: {
        format: { type: 'json_schema', schema: response_schema }
      }
    )

    http = Net::HTTP.new(API_URI.host, API_URI.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    response = http.request(req)

    unless response.is_a?(Net::HTTPSuccess)
      raise(
        TaggingService::Error,
        "Anthropic API error #{response.code}: #{response.body.truncate(200)}"
      )
    end

    JSON.parse(response.body)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise TaggingService::Error, "Anthropic API timeout: #{e.message}"
  rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => e
    raise TaggingService::Error, "Anthropic API connection error: #{e.message}"
  rescue JSON::ParserError => e
    raise TaggingService::Error, "Anthropic API invalid JSON: #{e.message}"
  end


  def parse_response(body)
    case body['stop_reason']
    when 'refusal'
      raise TaggingService::Error, 'Model declined to tag this name'
    when 'max_tokens'
      raise TaggingService::Error, 'Model response truncated (max_tokens)'
    end

    # The text may not be the first content block (e.g., after thinking)
    text_block = Array(body['content']).find { |b| b['type'] == 'text' }
    text = text_block&.dig('text').to_s
    parsed = JSON.parse(text)
    proposals = parsed['tags'] || []
    filter_proposals(proposals)
  rescue JSON::ParserError => e
    raise(
      TaggingService::Error,
      "Could not parse model response: #{e.message} — #{text.truncate(200)}"
    )
  end

  def api_key
    Rails.application.credentials.dig(:anthropic, :api_key) ||
      raise(TaggingService::Error, 'Anthropic API key not configured')
  end
end

