namespace :wikidata do
  desc 'Submit SeqCode accessions in batch to Wikidata'
  task push: :environment do
    client = WikidataClient.new
    client.login
    csrf_token = client.fetch_csrf_token
    names = 0
    recheck_after = 1.month # Taxa without an item are looked up again after this

    Name.all_valid.where(wikidata_item: nil)
        .where('wikidata_at IS NULL OR wikidata_at < ?', recheck_after.ago)
        .find_each do |name|
      entity_id = client.find_taxon_entity(name.name, name.rank)
      sleep 1 # WDQS rate limit applies to every query, not just pushes

      # Ignore taxa without wikidata item, but remember we checked
      if entity_id.nil?
        name.update_column(:wikidata_at, Time.current)
        next
      end

      puts "~ #{name.name}"

      if client.add_seqcode_claim(entity_id, name.id.to_s, csrf_token)
        # Save wikidata item to (1) link to WikiData and (2) keep track of
        # registered names
        name.update_column(:wikidata_item, entity_id)
      end

      names += 1
      break if names >= 1000
      sleep 1 # Rate limit for bots
    end

    puts "Saved accessions for #{names} names" unless names.zero?
  end
end

