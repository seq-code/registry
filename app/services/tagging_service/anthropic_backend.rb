require 'net/http'
require 'json'

class TaggingService::AnthropicBackend
  include TaggingService::Helpers

  API_URI = URI('https://api.anthropic.com/v1/messages').freeze
  MODEL   = 'claude-sonnet-5-5'
  MAX_TOKENS = 1024

  def propose(name)
    etym = etymology_text(name)
    raise TaggingService::Error, "No etymology for #{name.name}" if etym.blank?

    response = call_api(build_messages(name, etym))
    parse_response(response)
  end

  private

  def build_messages(name, etym)
    [{ role: 'user', content: build_prompt(name, etym) }]
  end

  def build_prompt(name, etym)
    <<~PROMPT
      You are a taxonomic nomenclature assistant. Given the etymology of a
      prokaryotic name, assign zero or more tags from the closed list below.

      ## Tag definitions

      Sub-tags are marked with their umbrella tag, as in "toponym (under
      geographic)"; tags without a marker are top-level.
      #{tag_definitions}

      ### Gender tags — assign ONLY for genus, species, or subspecies ranks
      Assign at most one of:
      - masculine, feminine, neuter, gender-uncertain
      `gender-uncertain` applies when masc. and fem. forms are identical
      (e.g. most participles) or when the protologue explicitly notes
      uncertainty.
      Endings shared between genders (e.g. -orum, -i, -um in masculine and
      neuter second-declension forms) do not determine gender on their own.
      Without an explicit statement in the etymology or the known gender of
      the referenced noun, assign no gender tag.

      ## Rules
      - Assign ALL tags that apply; they are not mutually exclusive
      - Umbrella terms can be assigned even if no children terms are
      - Assign an umbrella without any of its sub-tags only when the name
        clearly fits the umbrella but none of its sub-tags applies. For
        example, do not assign `commemorative` unless the name honours a
        person, organism, institution, or mythological or fictional figure.
      - Generic suffixes that denote a microorganism in general (e.g.
        -bacter, -bacterium, -monas, -microbium, -archaeum) never justify
        `phenonym` or `trait`, at any confidence level — not even medium or
        low. Likewise, a root describing where or how the organism lives
        (e.g. vivens, living, in a habitat compound) is `econym`, not
        `phenonym`.
      - The etymology is authoritative: when it explicitly states a gender, a
        formation type (e.g. "arbitrary name"), or the source of a reference,
        follow it even if the word's form suggests otherwise.
      - Use one of three confidence levels. "high": the tag follows directly
        from what the etymology states. "medium": the tag is reasonable but
        relies on a conventional or borderline reading (e.g. a shape suffix
        alone). "low": the tag requires interpretation beyond what is
        stated, or the name could plausibly fit other categories. When
        confidence would be low, prefer omitting the tag — a missed tag is
        less harmful than a wrong one, since proposals are reviewed by
        curators.
      - For every tag, set `basis` to the specific root, word, or name in the
        etymology on which the tag is based, written as it appears in the
        etymology (e.g. `Svalbard`, `telma`, `Vincent Gauci`, `ANSTO`). Use
        the root or word itself, not its gloss or grammar. If a tag has no
        specific basis in the etymology, do not propose it.

      ## Name to tag
      Name: #{name.name}
      Rank: #{name.rank}
      Etymology: #{etym}
    PROMPT
  end

  # Tag definitions from the database, with sub-tags nested and marked under
  # their umbrella tag and curation rules appended from +prompt_notes+
  def tag_definitions
    tags = Tag.with_rich_text_description.order(:name).to_a
    children = tags.group_by(&:parent_id)
    children[nil].to_a.flat_map do |tag|
      [tag_definition(tag)] +
        children[tag.id].to_a.map do |child|
          "  #{tag_definition(child, parent: tag)}"
        end
    end.join("\n")
  end

  def tag_definition(tag, parent: nil)
    label = parent ? "#{tag.slug} (under #{parent.slug})" : tag.slug
    line = "- #{label}: #{tag.description&.to_plain_text}"
    line += " [Note: #{tag.prompt_notes}]" if tag.prompt_notes.present?
    line
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

  def response_schema
    {
      type: 'object',
      properties: {
        tags: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              slug: { type: 'string', enum: Tag.order(:slug).pluck(:slug) },
              confidence: { type: 'string', enum: Tag::CONFIDENCE_LEVELS },
              basis: { type: 'string' }
            },
            required: %w[slug confidence basis],
            additionalProperties: false
          }
        }
      },
      required: %w[tags],
      additionalProperties: false
    }
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

