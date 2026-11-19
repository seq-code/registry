require 'net/http'
require 'json'

class TaggingService
  # Request and response handling shared by the backends that call a model
  # over HTTP, so they fail the same way. Including classes define
  # +service_name+, which prefixes their error messages (e.g. "Local model")
  module HttpBackend
    OPEN_TIMEOUT = 10

    private

    # Send +req+ to the host of +uri+ and return the parsed JSON body,
    # raising TaggingService::Error on any failure
    def send_request(req, uri, read_timeout)
      res = http_client(uri, read_timeout).request(req)
      unless res.is_a?(Net::HTTPSuccess)
        raise(
          TaggingService::Error,
          "#{service_name} error #{res.code}: #{res.body.to_s.truncate(200)}"
        )
      end

      JSON.parse(res.body)
    rescue Timeout::Error => e # Including Net::{Open,Read,Write}Timeout
      raise TaggingService::Error, "#{service_name} timeout: #{e.message}"
    rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => e
      raise(
        TaggingService::Error, "#{service_name} connection error: #{e.message}"
      )
    rescue Net::HTTPBadResponse, Net::ProtocolError => e
      # E.g., a server that doesn't speak HTTP (or not on that scheme)
      raise(
        TaggingService::Error, "#{service_name} protocol error: #{e.message}"
      )
    rescue JSON::ParserError => e
      raise TaggingService::Error, "#{service_name} invalid JSON: #{e.message}"
    end

    def http_client(uri, read_timeout)
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = read_timeout
      end
    end

    def raise_truncated
      raise TaggingService::Error, 'Model response truncated (max_tokens)'
    end

    # Valid proposals in the JSON +text+ answered by the model (see
    # Prompt#response_schema). The shape is checked, not only parsed, as
    # servers that ignore the schema may return any JSON
    def parse_proposals(text)
      text = text.to_s
      parsed = JSON.parse(text)
      tags = parsed['tags'] || [] if parsed.is_a?(Hash)
      unless tags.is_a?(Array)
        raise(
          TaggingService::Error,
          "Unexpected model response: #{text.truncate(200)}"
        )
      end

      filter_proposals(tags.grep(Hash))
    rescue JSON::ParserError => e
      raise(
        TaggingService::Error,
        "Could not parse model response: #{e.message} — #{text.truncate(200)}"
      )
    end
  end
end
