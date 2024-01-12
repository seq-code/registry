require 'serrano'
require 'date'

namespace :names do
  desc 'Extracts all names from saved works'
  task :find => :environment do |t, args|
    def usage(t)
      puts "Usage: rake names:find #{t}"
      exit 0
    end

    non_epithets = %w[
      by through for that has is as and are was were affiliated
      archaeon bacterium bacteria archaea a an transmitted
      belonging reveals community communities on which in clades? lineages?
      associated taxon taxa revised be the from infecting genes? particles?
      spp? species gen genus genera fam family families
      cla class classes classis ord ordo orders? phylum phyla
      instead of preferred provided list uncovers rhetoricae predominate[ds]?
      detection have genomes? like related associated infected lacks?
      pathosystems? into shares names? across do incorporate? represents?
      predominantly enrichment found members? includes? chromosomes? can with
      contains? distinct will at inhabiting living after to resulted remained
      appears? shuttles? forms? activates? cultures? remains? belongs? imply
    ]
    non_hyphen = %w[like related associated infected ]
    Publication.where(scanned: false).each do |pub|
      $stderr.puts "o #{pub.doi}"
      ca = "#{pub.title} #{pub.abstract}".
        gsub(/<[^>]+>/,'').gsub(/[^A-Za-z0-9 -]/,'.').gsub(/\s+/,' ').
        scan(/((:?Candidatus\.?|Ca\.) [A-Z][A-Za-z-]+(?: [a-z][A-Za-z-]+)?)/).
        map(&:first).map{ |i| i.sub(/^Ca\./,'Candidatus') unless i.nil? }.
        map{ |i| i.sub(/ (#{non_epithets.join('|')})$/i, '') unless i.nil? }.
        map{ |i| i.sub(/ (#{non_epithets.join('|')})$/i, '') unless i.nil? }.
        map{ |i| i.sub(/-(#{non_hyphen.join('|')})$/i, '') unless i.nil? }.
        map{ |i| i.remove '.' }.compact.sort.uniq
      ca.each do |name|
        next if name == 'Candidatus'

        $stderr.puts "  - #{name}"
        pub_names = pub.names.pluck(:name)
        unless pub_names.include? name
          n = Name.find_by_variants(name)
          n ||= Name.new(name: name).tap{ |i| i.save }
          unless pub_names.include? n.name
            PublicationName.new(publication: pub, name: n).save
          end
        end
      end
      pub.update(scanned: true)
    end

  end

end
