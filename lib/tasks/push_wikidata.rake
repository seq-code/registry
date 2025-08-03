namespace :wikidata do
  desc 'Submit SeqCode accessions in batch to Wikidata'
  task push: :environment do
    client = WikidataClient.new
    client.login
    csrf_token = client.fetch_csrf_token
    names = 0

    Name.all_valid.where(wikidata_item: nil).each do |name|
      puts "~ #{name.name}"

      entity_id = client.find_taxon_entity(name.name, name.rank)
      if entity_id.nil?
        puts "  > Taxon not found"
        next
      end

      if client.add_seqcode_claim(entity_id, name.id.to_s, csrf_token)
        # Save wikidata item to (1) link to WikiData and (2) keep track of
        # registered names
        name.update_column(:wikidata_item, entity_id)
      end

      names += 1
      if names > 3 break
      sleep 1 # Rate limit for bots
    end

    puts "Saved accessions for #{k} names"
  end
end

