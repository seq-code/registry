class SubmitRegisterToWikispeciesJob < ApplicationJob
  queue_as :default

  def perform(register, user)
    client = WikispeciesClientService.new(user.wikispecies_credential)

    register.update_column(:wikispecies_at, DateTime.now)
    register.update_name_order
    register.names_by_tree.each do |name|
      next if name.wikispecies_page_exists?

      name.submit_to_wikispecies!(client)
    end
  end
end
