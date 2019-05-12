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
        filter: { 'from-pub-date' => '2019-01-01',
          'until-pub-date' => '2020-01-01' } )
      unless works['status'] == 'ok'
        raise "#{works['message-type']}: #{
          works['message'].map{ |i| i['message'] }.join('; ') }"
      end
      # Parse results
      works['message']['items'].each do |work|
        $stderr.puts "o #{work['DOI']}"
        journal_loc = "#{work['volume']}"
        journal_loc += " (#{work['issue']})" if work['issue']
        params = {
          title: (work['title'] || []).join('. '),
          journal: (work['container-title'] || []).join('. '),
          journal_loc: journal_loc,
          journal_date: Date.new(*work['created']['date-parts'].first),
          doi: work['DOI'],
          url: work['URL'],
          pub_type: work['type'],
          abstract: work['abstract'],
          crossref_json: work.to_json
        }
        p = Publication.find_by(doi: work['DOI'])
        if p
          p.update(params)
          $stderr.puts "  Update id:#{p.id}"
        else
          p = Publication.new(params)
          unless p.save
            raise "Cannot save doi:#{work['DOI']}:\n#{p.errors.join("\n")}"
          end
          $stderr.puts "  Create id:#{p.id}"
        end
        (work['subject'] || []).each do |subject|
          next unless subject
          s = Subject.find_by name: subject
          next if s and p.subjects.include? s
          s ||= Subject.new(name: subject).tap{ |i| i.save }
          PublicationSubject.
            new(publication_id: p.id, subject_id: s.id).save
        end
        (work['author'] || []).each do |author|
          author['family'] ||= author['name']
          next unless author['family']
          a_params = { given: author['given'], family: author['family'] }
          a = Author.find_by a_params
          next if a and p.authors.include? a
          a ||= Author.new(a_params).tap{ |i| i.save }
          PublicationAuthor.
            new(publication_id: p.id, author_id: a.id,
              sequence: author['sequence']).save
        end
      end
      # Continue
      offset += 20
      break if offset > works['message']['total-results']
    end


  end

end
