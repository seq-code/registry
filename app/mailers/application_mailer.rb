class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name('no-reply@seqco.de', 'SeqCode Registry')
  layout 'mailer'
end
