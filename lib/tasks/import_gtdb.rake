
namespace :gtdb do
  desc 'Imports GTDB from FTP downloads'
  task :import, [:dir] => :environment do |t, args|
    def usage(t)
      puts "Usage: rake #{t}[gtdb-release-dir]"
      exit 0
    end

    def find_or_create_name(name, rank, accession)
      k = [rank, name, accession]
      @cached_names ||= {}
      @cached_names[k] ||= Name.find_by_variants(name)
      if @cached_names[k].present? &&
            @cached_names[k].inferred_rank.to_sym != rank
        # Ignore cross-rank homonyms
        return(@cached_names[k] = [])
      end

      if @cached_names[k]
        unless @cached_names[k].is_a?(Array) ||
               @cached_names[k].gtdb_accession == accession
          @cached_names[k].update_column(:gtdb_accession, accession)
        end
      else
        @n_name += 1
        @cached_names[k] = Name.create!(
          name: name, rank: rank, gtdb_accession: accession
        )
      end
      @cached_names[k]
    end

    def register_string(string)
      @names_done ||= {}
      ranks = {
        'd' => :domain, 'p' => :phylum, 'c' => :class, 'o' => :order,
        'f' => :family, 'g' => :genus,  's' => :species
      }
      names =
        string.split(';').map { |i| i.split('__', 2) }
          .map do |i|
            [ranks[i[0]], i[1], "#{i[0]}__#{i[1]}"]
          end
          .map do |i|
            ((i[0] == :species && i[1] =~ /^[A-Z][a-z]+ [a-z]+$/) ||
              (i[0] != :species && i[1] =~ /^[A-Z][a-z]+$/)) ? i : nil
          end

      names.each_with_index do |n, k|
        next if n.nil? || k == 0 || @names_done[n]
        next if (p = names[k - 1]).nil?
        @names_done[n] = true

        name = find_or_create_name(n[1], n[0], n[2])
        parent = find_or_create_name(p[1], p[0], p[2])
        next unless name.present? && parent.present?

        placement =
          Placement
            .create_with(gtdb_taxonomy: true)
            .find_or_create_by(name: name, parent: parent)

        placement.update_column(:gtdb_taxonomy, true)
        if name.placement.nil? && (name.parent.nil? || name.parent == parent)
          placement.update(preferred: true)
        end
      end
    end

    usage(t) unless args[:dir]
    @n_name = 0
    Placement.update_all(gtdb_taxonomy: false)
    Dir[args[:dir] + '/*_taxonomy*.tsv.gz'].each do |file|
      $stderr.puts "Reading: #{file}"
      File.open(file) do |fh|
        lno = 0
        last_str = nil
        Zlib::GzipReader.new(fh).each do |ln|
          $stderr.print "- #{lno += 1} \r"
          str = ln.chomp.split("\t", 2)[1]
          register_string(str) unless str == last_str
          last_str = str
        end
        $stderr.puts
      end
    end

    $stderr.puts "Names created: #{@n_name}"
    $stderr.puts "Reported placements: #{
      Placement.where(gtdb_taxonomy: true).count
    }"
  end

end
