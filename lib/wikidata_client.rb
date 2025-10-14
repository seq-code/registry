require 'httparty'

class WikidataClient

  attr_accessor :base_url

  def initialize
    # Connection configuration
    @base_url = 'https://www.wikidata.org/w/api.php'
    @username = Rails.application.credentials.dig(:wikidata, :username)
    @password = Rails.application.credentials.dig(:wikidata, :password)
    @cookies  = HTTParty::CookieHash.new
    @headers  = {
      'Content-Type' => 'application/x-www-form-urlencoded',
      'User-Agent' =>
        'SeqCodeBot/1.0 ' \
        '(https://registry.seqco.de/; bot@seqco.de) ' \
        'SeqCode Registry/1.0'
    }

    # SeqCode-specific configuration
    @accession_property = 'P13490'
  end

  def get(hash)
    res = HTTParty.get(base_url, hash.merge(
      headers: @headers,
      cookies: @cookies
    ))
    set_cookies = res.headers['set-cookie']
    @cookies.add_cookies(set_cookies) if set_cookies.present?
    res
  end

  def post(hash)
    res = HTTParty.post(base_url, hash.merge(
      headers: @headers,
      cookies: @cookies
    ))
    set_cookies = res.headers['set-cookie']
    @cookies.add_cookies(set_cookies) if set_cookies.present?
    res
  end

  def login
    # Get login token
    res = get(
      query: {
        action: 'query',
        meta:   'tokens',
        type:   'login',
        format: 'json'
      }
    )

    body = JSON.parse(res.body)
    token = body.dig('query', 'tokens', 'logintoken')

    # Log in using bot credentials
    login_res = post(
      query: { format: 'json' },
      body: {
        action: 'login',
        lgname: @username,
        lgpassword: @password,
        lgtoken: token
      }
    )

    login_body = JSON.parse(login_res.body)
    result = login_body.dig('login', 'result')
    raise "Login failed: #{result}" unless result == 'Success'

    true
  end

  def fetch_csrf_token
    res = get(
      query: {
        action: 'query',
        meta:   'tokens',
        type:   'csrf',
        format: 'json'
      }
    )

    token = res.parsed_response.dig('query', 'tokens', 'csrftoken')
    raise 'Failed to fetch CSRF token' unless token && token.length > 10
    token
  end

  def add_seqcode_claim(entity_id, seqcode_accession, csrf_token)
    if claim_exists?(entity_id, @accession_property, seqcode_accession)
      puts "SeqCode #{seqcode_accession} already exists for #{entity_id}"
      return
    end

    body = {
      action:   'wbcreateclaim',
      entity:   entity_id,
      property: @accession_property,
      snaktype: 'value',
      value:    seqcode_accession.to_json,
      token:    csrf_token,
      format:   'json',
      summary:  'Adding SeqCode Registry accession via SeqCodeBot',
      bot:      true
    }

    res = post(body: URI.encode_www_form(body))

    begin
      response_body = JSON.parse(res.body)
    rescue JSON::ParserError
      puts "API response was not JSON:\n#{res.body}"
      return
    end

    if response_body['success'] == 1
      claim_id = response_body.dig('claim', 'id')
      puts "Success: #{entity_id} <- #{seqcode_accession} (claim: #{claim_id})"
      add_reference_to_claim(claim_id, csrf_token)
    else
      puts "Failed to add claim: #{response_body}"
      return
    end

    true
  end

  def find_taxon_entity(name, rank)
    rank_qid = {
      subspecies: 'Q68947',
      species: 'Q7432',
      genus:   'Q34740',
      family:  'Q35409',
      order:   'Q36602',
      class:   'Q37517',
      phylum:  'Q38348',
      kingdom: 'Q36732',
      domain:  'Q146481'
    }[rank.to_sym] or raise "Unknown rank: #{rank}"

    query = <<~SPARQL
      SELECT ?item WHERE {
        ?item wdt:P31 wd:Q16521;
              wdt:P225 "#{name}";
              wdt:P105 wd:#{rank_qid}.
      }
      LIMIT 1
    SPARQL

    encoded_query = URI.encode_www_form_component(query)
    url = "https://query.wikidata.org/sparql?query=#{encoded_query}"

    res = HTTParty.get(url, headers: {
      'Accept' => 'application/sparql-results+json',
      'User-Agent' => 'SeqCodeBot/0.1 (bot@seqco.de)'
    })

    begin
      json = JSON.parse(res.body)
      entity_url = json.dig('results', 'bindings', 0, 'item', 'value')
      return entity_url.split('/').last if entity_url
    rescue JSON::ParserError => e
      raise "Failed to parse SPARQL result: #{e}"
    end

    nil
  end

  ##
  # Check if the claim exists for +entity_id+ to have +property+ with +value+.
  # If +value+ is +nil+, check if the property is set at all (with any value)
  def claim_exists?(entity_id, property, value = nil)
    res = get(query: {
      action: 'wbgetentities',
      ids: entity_id,
      props: 'claims',
      format: 'json'
    })

    claims = res.parsed_response.dig('entities', entity_id, 'claims', property)
    return false unless claims

    claims.any? do |claim|
      mainsnak = claim['mainsnak']
      mainsnak['snaktype'] == 'value' &&
        mainsnak['datatype'] == 'external-id' &&
        mainsnak['datavalue'] &&
        (value.nil? || mainsnak['datavalue']['value'] == value)
    end
  end

  def add_reference_to_claim(claim_id, csrf_token)
    snak_ref = {
      snaktype: 'value',
      property: 'P248', # stated in
      datavalue: {
        value: {
          'entity-type': 'item',
          'numeric-id': 119959538
        },
        type: 'wikibase-entityid'
      }
    }
    snak_time = {
      snaktype: 'value',
      property: 'P813', # retrieved
      datavalue: {
        value: {
          time: Time.now.utc.strftime('+%Y-%m-%dT00:00:00Z'),
          precision: 11,
          timezone: 0,
          before: 0,
          after: 0,
          calendarmodel: 'http://www.wikidata.org/entity/Q1985727'
        },
        type: 'time'
      }
    }
    body = {
      action: 'wbsetreference',
      statement: claim_id,
      snaks: { P248: [snak_ref, snak_time] }.to_json,
      token: csrf_token,
      format: 'json',
      summary: 'Adding source: SeqCode Registry via SeqCodeBot',
      bot: true
    }
    res = post(body: URI.encode_www_form(body))

    begin
      parsed = JSON.parse(res.body)
    rescue JSON::ParserError
      raise "Reference API response was not JSON:\n#{res.body}"
    end

    if parsed['success'] == 1
      puts "Reference added to claim #{claim_id}"
    else
      puts "Failed to add reference: #{parsed}"
    end
  end
end
