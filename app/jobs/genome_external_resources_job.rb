class GenomeExternalResourcesJob < ApplicationJob
  queue_as :default

  def perform(*genomes)
    genomes.each(&:reload_source_json!)
  end
end
