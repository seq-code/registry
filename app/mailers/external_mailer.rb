class ExternalMailer < ApplicationMailer
  layout 'external_mailer'

  ##
  # Simple email without any defaults
  def simple_email(message)
    @message = message
    mail(params)
  end
end
