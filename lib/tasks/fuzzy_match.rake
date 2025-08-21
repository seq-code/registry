namespace :name do
  desc 'Fuzzy match a name against the Name model'
  task :fuzzy_match, [:query, :method] => :environment do |t, args|
    query = args[:query]
    method = (args[:method] || 'similarity').to_sym

    if query.blank?
      puts <<~HELP
        Please provide a query string
        Example: rake name:fuzzy_match['Escherichia coli','similarity']
      HELP
      exit
    end

    if ActiveRecord::Base.connection.adapter_name != 'PostgreSQL'
      puts <<~ERROR
        Fuzzy matching requires PostgreSQL
        Current adapter: #{ActiveRecord::Base.connection.adapter_name}
      ERROR
      exit 1
    end

    puts "Searching for fuzzy matches to: '#{query}'\n\n"

    matches = Name.fuzzy_match(query, method: method)
    if matches.any?
      matches.each do |match|
        puts "Match: #{match.name} (Similarity: #{match.score})"
      end
    else
      puts 'No close matches found.'
    end
  end
end

