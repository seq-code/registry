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
      For these ranks, always try to infer the gender of the name (the genus
      name, or the epithet of a species or subspecies), even when the
      etymology does not state it. Apply the first of these rules that
      resolves it:
      1. A gender stated in the etymology for the name itself is
         authoritative. A statement of several genders (e.g. "masc. / fem.
         adj.") only means the form is shared; apply the rules below.
      2. An adjectival or participial epithet, including present participles
         in -ans or -ens, takes the gender of the genus it is combined with
         (see "Genus gender" below). When the genus gender is not recorded,
         infer it from the genus name itself (e.g. -coccus, -bacter, and
         -bacillus are masculine; -monas and -ella are feminine; -bacterium
         is neuter) rather than treating it as unknown.
      3. An epithet that is a noun in the genitive takes the gender of that
         noun, not of the genus:
         - If the etymology names the noun in the nominative (e.g. "of
           Sargassum", "of the prawn genus Penaeus"), infer the gender from
           that nominative, including plurals (e.g. Crinocheta, a neuter
           plural).
         - A bare second-declension genitive in -i is ambiguous between -us
           (masculine) and -um (neuter); do not default to masculine.
         - Genitives of personal names in -i or -ii are masculine, and in
           -ae or -iae feminine.
         - Otherwise, use the standard gender of the Latin or Greek noun
           (e.g. abyssus is feminine, termes is masculine).
      4. A noun in apposition takes its own gender.
      In New Latin etymologies, salt names in -as, -atis (e.g. phosphas,
      nitras, sulfas) are masculine.
      Use gender-uncertain only when none of these rules resolves the gender
      (e.g. an adjectival epithet whose genus name does not reveal its
      gender, or a bare genitive in -i whose nominative is not given). A gender not stated in
      the etymology for the name itself takes at most medium confidence.

      ## Rules
      - Assign ALL tags that apply; they are not mutually exclusive
      - Tag what the name itself refers to, not places, institutions, or
        other context that the etymology mentions only to explain the name
        (e.g. Bilamarchaeum means "turtle lands"; the study site mentioned
        is context, not a `toponym`).
      - Hosts and habitats:
        - A named body part or organ used as habitat (e.g. gut, rumen,
          liver) is `econym`.
        - A host taxon (e.g. a coral or sponge genus in -cola names) is
          `organonym`, not `econym`.
        - A name referring to both gets both (e.g. hominiciens, "in the
          human gut").
        - Mere position relative to a host (e.g. endo-, ecto-, "inside",
          "outside") is neither.
        - Words describing the habitat are `econym`, not `phenonym`, even
          when formed from a verb or participle (e.g. mesodigestus,
          "referring to a mesophilic digester").
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
      - `chemonym` and `phenonym` are independent of each other:
        - `chemonym`: the name refers to a chemical substance or particle
          (element, ion, compound, functional group, chemical mixture such
          as oil or salt, or a particle such as the electron). Decide by
          what the root names, not by what it says about the organism.
        - `phenonym`: the name describes a phenotypic or physiological
          property of the organism itself, including metabolism (substrates
          used or degraded, compounds produced, or processes such as
          nitrogen fixation or fermentation).
        For example, "sulfur-metabolizing" and "electron-eating" get both,
        "fermenting" gets only `phenonym`, and "of oil sand" or "belonging
        to salt" (habitats) get only `chemonym`.
      - A mythological or fictional character is a `mythonym`, not an
        `organonym`, even when the character is an animal.
      - Names referring to the organism's size (e.g. nano-, micro-,
        minutus) get both `phenonym` (with `trait`) and `dimensional`.
        Assign `dimensional` on its own, without any of its sub-tags. The
        generic suffix -microbium is not a size reference.
      - Diminutive suffixes (e.g. -ellum, -ella, -ula) are generic: they
        never justify `phenonym` or `dimensional`.
      - `classical` applies only to a name or epithet that is a single word
        from a dormant language, used largely unmodified. A compound or
        neologism is not `classical`, even when every root is classical
        (e.g. Elulimicrobium). If you propose `classical` for a compound at
        all, use low confidence.
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
        curators. This does not apply to gender tags, which should always be
        assigned for genus, species, and subspecies ranks (see above).
      - For every tag, set `basis` to the specific root, word, or name in the
        etymology on which the tag is based, written as it appears in the
        etymology (e.g. `Svalbard`, `telma`, `Vincent Gauci`, `ANSTO`). Use
        the root or word itself, not its gloss or grammar. For a gender
        taken from the genus, use the genus name. If any other tag has no
        specific basis in the etymology, do not propose it.

      ## Name to tag
      Name: #{name.name}
      Rank: #{name.rank}
      Etymology: #{etym}
      #{genus_gender_line(name)}
    PROMPT
  end

  # Gender of the genus for species and subspecies (see the gender rules of
  # the prompt), or nil for other ranks
  def genus_gender_line(name)
    return unless %w[species subspecies].include?(name.rank)

    slug, source = genus_gender(name)
    if slug
      "Genus gender: #{slug} (#{source})"
    else
      genus = name.genus&.name || name.name.sub(/\ACandidatus /, '').split.first
      "Genus gender: not recorded; infer it from the genus name #{genus}"
    end
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

