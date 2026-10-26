require 'net/http'
require 'json'

class TaggingService::AnthropicBackend
  include TaggingService::Helpers

  API_URI = URI('https://api.anthropic.com/v1/messages').freeze
  MODEL   = 'claude-sonnet-4-6'
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
      Respond ONLY with a JSON object — no explanation, no markdown, no
      preamble.

      ## Tag definitions

      ### Umbrella tags (assign the umbrella whenever you assign a sub-tag)
      - geographic: name references a place or environment
        - toponym: named after a real geographic place (country, region, city,
          river, lake, ocean, mountain, etc.)
        - econym: named after a habitat or environmental feature
          (e.g. marinus, lacustris, thermophilus)
        - fictional-place: named after a fictional or mythological place
        - metronym: named after a measurement, coordinate, or physical
          parameter (depth, elevation, etc.); also add "trait" umbrella if the
          parameter is physiological/ecological rather than locational
      - commemorative: name references a named entity
        - eponym: named after a real person
        - organonym: named after another organism or taxon (not a substrate)
        - institutonym: named after an institution, project, or organization
        - mythonym: named after a deity, mythological figure, or fictional
          person/character
      - trait: name describes a property of the organism or its context
        - phenonym: named after a phenotypic trait (morphology, pigmentation,
          physiology, etc.)
        - chemonym: named after a chemical compound, element, or metabolic
          property
        - chrononym: named after a time, period, season, or calendar unit
          (geological eras, seasons, times of day, calendar-specific periods
          such as a harvest month); also add "phenonym" if it describes a
          biological activity pattern, or "econym" if seasonal environmental
        - numeronym: named after a number, quantity, or order — including
          ordinal/sequential use (e.g. primus for first discovered)
      - formed: name whose construction is the defining feature
        - acronym: formed from initials or an abbreviation
        - arbitrary: constructed for phonotactic/orthographic reasons; roots
          may still be identifiable; can co-occur with content tags

      ### Cross-cutting tags (no umbrella)
      - mythological: assign whenever you assign "fictional-place" or "mythonym"
      - classical: epithet is a direct word from a dormant scholarly language
        (Latin, Ancient Greek, Sanskrit, etc.) used largely unmodified — not a
        constructed compound or commemorative; can co-occur with content tags

      ### Gender tags — assign ONLY for genus, species, or subspecies ranks
      Assign exactly one of:
      - masculine, feminine, neuter, gender-uncertain
      gender-uncertain applies when masc. and fem. forms are identical
      (e.g. most participles) or when the protologue explicitly notes
      uncertainty.

      ## Rules
      - Assign ALL tags that apply; they are not mutually exclusive
      - Always assign the umbrella tag when assigning any of its sub-tags
      - Use confidence "low" when the assignment requires inference beyond
        what is explicitly stated in the etymology, or when two tags are
        plausible but you cannot determine which applies

      ## Name to tag
      Name: #{name.name}
      Rank: #{name.rank}
      Etymology: #{etym}

      ## Required response format
      {"tags": [{"slug": "eponym", "confidence": "high"}, ...]}
    PROMPT
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
      messages: messages
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
    # The text may not be the first content block (e.g., after thinking)
    text_block = Array(body['content']).find { |b| b['type'] == 'text' }
    text = text_block&.dig('text').to_s.strip
    # Strip markdown code fences if the model adds them despite instructions
    text = text.gsub(/\A```(?:json)?\n?/, '').gsub(/\n?```\z/, '').strip
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

