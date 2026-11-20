namespace :tags do
  # Prerequisite of the tags:* tasks (so it has no description, and isn't
  # listed by rake -T): use the backend named in the TAGGING_BACKEND env var
  # (e.g. TAGGING_BACKEND=local), if set, instead of the one configured in
  # credentials (see config/initializers/tagging.rb)
  task backend: :environment do
    name = ENV['TAGGING_BACKEND'].presence or next

    Rails.configuration.tagging_backend = name.strip.downcase.to_sym
    TaggingService.backend # Validate it before running the task
  rescue TaggingService::Error => e
    abort "Invalid TAGGING_BACKEND: #{e.message}"
  end
end
