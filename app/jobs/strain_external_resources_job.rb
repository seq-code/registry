class StrainExternalResourcesJob < ApplicationJob
  queue_as :default

  def perform(*strains)
    strains.each(&:reload_strain_info_json!)
  end
end
