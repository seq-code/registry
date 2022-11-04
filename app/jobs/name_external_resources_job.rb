class NameExternalResourcesJob < ApplicationJob
  queue_as :default

  def perform(*names)
    names.each do |name|
      Name.transaction do
        name.make_external_requests = true
        name.external_homonyms
        name.gbif_homonyms
        name.queued_external = nil
        name.save(touch: false)
        name.make_external_requests = false
      end
    end
  end
end
