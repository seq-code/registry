require 'net/http'

# Proxy for the dictionary lookups of the etymology table, which the browser
# can't send to the Perseus Digital Library directly (it doesn't allow
# cross-origin requests). Only two Perseus services are available, with
# validated parameters, and responses are cached for a long time, so
# repeated lookups never reach Perseus. Requests are also rate limited per
# IP (see config/initializers/rack_attack.rb)
class DictionaryController < ApplicationController
  PERSEUS = 'https://www.perseus.tufts.edu/hopper/'.freeze

  # A single word, with an optional homograph number in dictionary entries
  # (e.g. "pars1")
  WORD = /[[:alpha:]]{1,40}/.freeze

  # Lewis & Short, and Elementary Lewis
  DICTIONARIES = %w[Perseus:text:1999.04.0059 Perseus:text:1999.04.0060].freeze

  # Accepted parameters of each service, with the pattern of their values
  SERVICES = {
    'xmlmorph' => {
      'lang' => /\Ala\z/,
      'lookup' => /\A#{WORD}\z/
    },
    'loadquery' => {
      'doc' => /\A(#{DICTIONARIES.map { |d| Regexp.escape(d) }.join('|')}):
                entry=#{WORD}\d{0,2}\z/x
    }
  }.freeze

  CACHE_TTL = 30.days
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  # Cached in place of a response for entries that don't exist, for a
  # shorter time (Perseus reports them as server errors, so a genuine error
  # shouldn't be remembered for long)
  NOT_FOUND = :not_found
  NOT_FOUND_TTL = 1.day

  class PerseusError < StandardError
  end

  class EntryNotFound < StandardError
  end

  # GET /dictionary/:service
  def show
    service = params[:service]
    query = request.query_parameters
    unless valid_query?(service, query) && request.xhr?
      return render_error('Invalid dictionary request', :bad_request)
    end

    body = cached_response(service, query)
    return render_error('Term not found', :not_found) if body == NOT_FOUND

    # Served as plain text so the third-party content is never rendered as a
    # page of the Registry; the script parses it
    render(plain: body, content_type: 'text/plain')
  rescue PerseusError => e
    render_error(e.message, :bad_gateway)
  end

  private

  def valid_query?(service, query)
    expected = SERVICES[service] or return false
    query.keys.sort == expected.keys.sort &&
      expected.all? { |key, pattern| query[key].to_s.match?(pattern) }
  end

  # The cached response of +service+ for +query+ (or NOT_FOUND), fetching it
  # from Perseus if it isn't cached. Failures are not cached
  def cached_response(service, query)
    key = ['perseus', service, query.sort.to_h]
    cached = Rails.cache.read(key)
    return cached unless cached.nil?

    body = fetch_perseus(service, query)
    Rails.cache.write(key, body, expires_in: CACHE_TTL)
    body
  rescue EntryNotFound
    Rails.cache.write(key, NOT_FOUND, expires_in: NOT_FOUND_TTL)
    NOT_FOUND
  end

  # Body of the Perseus +service+ response for +query+. Raises EntryNotFound
  # for dictionary entries that don't exist, and PerseusError if Perseus
  # can't be reached, times out, or refuses the request
  def fetch_perseus(service, query)
    if Rails.configuration.bypass_external_apis
      raise(PerseusError, 'External APIs are disabled')
    end

    uri = URI(PERSEUS + service)
    uri.query = URI.encode_www_form(query)
    response =
      Net::HTTP.start(
        uri.host, uri.port, use_ssl: true,
        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT
      ) do |http|
        http.get(
          uri.request_uri,
          'User-Agent' => HasExternalResources::EXTERNAL_USER_AGENT
        )
      end
    # Missing dictionary entries are reported as server errors
    if service == 'loadquery' && response.code == '500'
      raise(EntryNotFound)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("Perseus #{service} returned #{response.code}")
      raise(
        PerseusError,
        'The Perseus Digital Library refused the request ' \
        "(HTTP #{response.code})"
      )
    end

    response.body.force_encoding(Encoding::UTF_8)
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise(PerseusError, 'The Perseus Digital Library did not respond in time')
  rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
    raise(PerseusError, 'The Perseus Digital Library could not be reached')
  end

  def render_error(message, status)
    render(json: { error: message }, status: status)
  end
end
