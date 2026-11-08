class Rack::Attack
  throttle('req/ip', limit: 20, period: 1.minute) do |req|
    req.ip if req.path == '/publications'
  end

  # Dictionary lookups proxied to Perseus (see DictionaryController)
  throttle('dictionary/ip', limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/dictionary/')
  end
end

