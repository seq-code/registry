# DKIM global configuration
if Rails.env.production?
  Dkim::domain      = 'seqco.de'
  Dkim::selector    = 'mail'
  pem_key = File.join(Rails.root, '..', 'dkim_private.pem')
  Dkim::private_key = open(pem_key).read

  # This will sign all ActionMailer deliveries
  ActionMailer::Base.register_interceptor(Dkim::Interceptor)
end

