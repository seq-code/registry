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
      across activates? affiliated after an? and appears? archaea archaeon are
      as associated at bacteria bacterium be belonging belongs? by
      can chromosomes? cla clades? class class[ei]s communities community
      contains? cultures? decreased? detection distinct do enrichment
      facilitate[ds]? fam families family for forms? found from
      gen genes? genomes? genus genera has have
      imply in includes? incorporate? infected infecting inhabiting instead into
      is lacks? lineages? like list living members? names?
      of on ord orders? ordo
      particles? pathosystems? phyla phylum populations? predominantly
      predominate[ds]? preferred provided
      recovered related remained remains? represents? resulted reveals revised
      shares shuttles? species spp? symbiont
      taxa taxon that the through to transmitted
      uncovers was were which will with
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
