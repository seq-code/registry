# config/initializers/services.rb
# Ensure service objects are loaded before views are rendered
Rails.application.config.to_prepare do
  # Load all service objects under app/services/
  Dir.glob(Rails.root.join('app/services/**/*.rb')).each do |file|
    require_dependency file
  end
end
