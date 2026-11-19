class TaggingService::AnthropicBackend
  include TaggingService::Prompt
  include TaggingService::HttpBackend

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

  # The static part of the prompt (see Prompt#system_prompt), as a system
  # block marked for caching
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
    send_request(req, API_URI, 30)
  end

  def service_name
    'Anthropic API'
  end

  def parse_response(body)
    case body['stop_reason']
    when 'refusal'
      raise TaggingService::Error, 'Model declined to tag this name'
    when 'max_tokens'
      raise_truncated
    end

    # The text may not be the first content block (e.g., after thinking)
    text_block = Array(body['content']).find { |b| b['type'] == 'text' }
    parse_proposals(text_block&.dig('text'))
  end

  def api_key
    Rails.application.credentials.dig(:anthropic, :api_key) ||
      raise(TaggingService::Error, 'Anthropic API key not configured')
  end
end

