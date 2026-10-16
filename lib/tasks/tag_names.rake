namespace :tags do
  desc 'Propose tags for untagged names using the LLM service (not yet implemented)'
  task propose: :environment do
    # TODO: iterate Name records with no accepted NameTags,
    # call a tagging service, create NameTag(status_int: 0, proposed_by: 'llm')
    puts 'LLM tagging service not yet implemented.'
  end
end
