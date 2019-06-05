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
    
    offset = 0
    loop do
      # Query CrossRef
      works = Serrano.works(query: 'candidatus',
        sort: 'deposited', order: 'asc', offset: offset,
        filter: { 'from-pub-date' => (Date.today - 4.months).to_s,
          'until-pub-date' => (Date.today + 3.months).to_s} )
      unless works['status'] == 'ok'
        raise "#{works['message-type']}: #{
          works['message'].map{ |i| i['message'] }.join('; ') }"
      end
      # Parse results
      works['message']['items'].each do |work|
        $stderr.puts "o #{work['DOI']}"
        p = Publication.by_serrano_work(work)
        p.new_record? and
          raise "Cannot save doi:#{work['DOI']}:\n#{p.errors.join("\n")}"
      end
      # Continue
      offset += 20
      break if offset > works['message']['total-results']
    end


  end

end
