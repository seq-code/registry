namespace :authors do
  desc 'Standardize author names, find duplicates, and merge them'
  task :clean => :environment do |t, args|
    km = 0
    ks = 0
    Author.all.each do |author|
      next if author.standard_name?

      par = {
        family: Author.standardize_family(author.family),
        given: Author.standardize_given(author.given)
      }

      if s_author = Author.find_by(par)
        puts '~ Merging %s -> %s' % [author.full_name, s_author.full_name]
        # Replace all associations
        author.publication_authors.update(author: s_author)
        author.contacts.update(author: s_author)
        # And remove
        author.destroy
        km += 1
      else
        puts '~ Standardizing %s' % [author.full_name]
        author.update(par)
        ks += 1
      end
    end
    puts 'Merged %i authors and standardized %s names' % [km, ks]
  end
end
