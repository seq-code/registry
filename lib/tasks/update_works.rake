require 'serrano'
require 'date'

Serrano.configuration do |config|
  config.mailto = 'miguel@rodriguez-r.com'
end

namespace :works do
  desc 'Downloads all works since last update'
  task :update => :environment do |t, args|
    def usage(t)
      puts "Usage: rake works:update #{t}"
      exit 0
    end

    include ApplicationHelper

    Publication.query_crossref(
      query: 'candidatus',
      sort: 'deposited', order: 'asc',
      filter: {
        'from_pub_date' => (Date.today - 3.months).to_s,
        'until_pub_date' => (Date.today).to_s
      }
    ) { |pub| $stderr.puts "o #{pub.doi}" }
  end
end
