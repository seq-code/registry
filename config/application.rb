require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CandidatusExcubia
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Boolean handling of SQLite3
    config.active_record.sqlite3&.represent_boolean_as_integer = true

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Define mailer job method
    config.action_mailer.delivery_job = 'ActionMailer::MailDeliveryJob'

    # Make sure Flash is always present even if api_only=true
    config.middleware.use ActionDispatch::Flash
  end
end
