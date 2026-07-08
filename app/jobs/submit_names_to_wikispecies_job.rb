class SubmitNamesToWikispeciesJob < ApplicationJob
  queue_as :default

  def perform(register, access_token:)
    client = WikispeciesClientService.new(access_token: access_token)

    register.names_by_rank.each do |name|
      next if name.wikispecies_page_exists?

      name.submit_to_wikispecies!(client)
    end
  end
end
