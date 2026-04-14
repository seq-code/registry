class Rack::Attack
  throttle('req/ip', limit: 20, period: 1.minute) do |req|
    req.ip if req.path == '/publications'
  end
end

