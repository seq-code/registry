class NameExternalResourcesJob < ApplicationJob
  queue_as :default

  def perform(*names)
    names.each do |name|
      name.make_external_requests = true
      Name.transaction do
        name.external_homonyms
        name.update(queued_external: nil)
      end
    end
  end
end
