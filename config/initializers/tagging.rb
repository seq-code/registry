# Backend for the TaggingService: :anthropic or :local
# Set via credentials: tagging: backend: anthropic
Rails.application.config.tagging_backend =
  Rails.application.credentials.dig(:tagging, :backend)&.to_sym || :anthropic

