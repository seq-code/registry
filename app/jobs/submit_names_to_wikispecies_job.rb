class SubmitNamesToWikispeciesJob < ApplicationJob
  queue_as :default

  def perform(register, user)
    client = WikispeciesClientService.new(user.wikispecies_credential)

    register.names_by_rank.each do |name|
      next if name.wikispecies_page_exists?

      name.submit_to_wikispecies!(client)
    end
  end
end
