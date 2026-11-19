# Backend for the TaggingService: :anthropic or :local
# Set via credentials: tagging: backend: anthropic
# The tags:* rake tasks can override it with the TAGGING_BACKEND env var
# (see lib/tasks/tags.rake)
Rails.application.config.tagging_backend =
  Rails.application.credentials.dig(:tagging, :backend)&.to_sym || :anthropic

