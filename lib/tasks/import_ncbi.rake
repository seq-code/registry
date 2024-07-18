
namespace :ncbi do
  desc 'Imports NCBI taxonomy from FTP dump'
  task :import, [:dir] => :environment do |t, args|
    def usage(t)
      puts "Usage: rake #{t}[ncbi-taxonomy-dump-dir]"
      exit 0
    end

    def find_or_create_name(name, rank)
      k = [rank, name]
      @cached_names ||= {}
      return Name.find(@cached_names[k]) if @cached_names[k].present?

      name_obj = Name.find_by_variants(name)
      if name_obj.present? && name_obj.inferred_rank.to_sym != rank
        return(@cached_names[k] = [])
      end
      return name_obj if name_obj

      @n_name += 1
      name_obj = Name.create!(name: name, rank: rank)
      @cached_names[k] = name_obj.id
      return name_obj
    end

    def read_names_dmp(file)
      $stderr.puts "Reading: #{file}"
      names = {}
      File.open(file) do |fh|
        fh.each_with_index do |ln, k|
          $stderr.print "- #{k} \r"
          row = ln.split(/\t\|\t?/)
          next unless row[3] == 'scientific name'
          names[row[0].to_i] = row[1].strip
        end
        $stderr.puts
      end
      Hash[names.sort]
    end

    def read_nodes_dmp(file)
      $stderr.puts "Reading: #{file}"
      nodes = []
      File.open(file) do |fh|
        fh.each_with_index do |ln, k|
          $stderr.print "- #{k} \r"
          row = ln.split(/\t\|\t?/)
          v = [row[1].to_i, row[2].to_sym]
          v[1] = :domain if v[1] == :superkingdom
          nodes[row[0].to_i] = v
        end
        $stderr.puts
      end
      nodes
    end

    def domain(taxid, nodes)
      while nodes[taxid][1] != :domain
        return nil if taxid == nodes[taxid][0]
        taxid = nodes[taxid][0]
      end
      return taxid if nodes[taxid][1] == :domain
    end

    def filter_names_by_domain(names, nodes, ranks)
      $stderr.puts 'Using only prokaryotic names'
      non_epithet = %w[bacterium archaeon cyanobacterium]
      new_names = {}
      i = 0
      names.each do |k, n|
        $stderr.print "- #{i += 1}/#{names.size} \r"
        next unless n && ranks.include?(nodes[k][1])
        case nodes[k][1]
        when :species
          next if n !~ /^[A-Z][a-z]+ [a-z]+$/
          next if non_epithet.include?(n.split(/ +/, 2)[1])
        when :subspecies
          next if n !~ /^[A-Z][a-z]+ [a-z]+ subsp\. [a-z]+$/
        else
          next if n !~ /^[A-Z][a-z]+$/
        end
        next unless [2, 2157].include?(domain(k, nodes))

        new_names[k] = n
      end
      $stderr.puts
      Hash[new_names.sort]
    end

    def register_name(taxid, name, names, nodes, ranks)
      return unless taxid && nodes[taxid][1] == name.inferred_rank.to_sym

      name.update(ncbi_taxonomy: taxid)
      parent_node = nodes[taxid] or return

      while !ranks.include?(pn_rank = nodes[parent_node[0]][1])
        parent_node = nodes[parent_node[0]]
      end
      return if ranks[-1] == pn_rank || !names[parent_node[0]]

      parent = find_or_create_name(names[parent_node[0]], pn_rank)
      return unless parent.present?

      placement =
        Placement
          .create_with(ncbi_taxonomy: true)
          .find_or_create_by(name: name, parent: parent)

      placement.update_column(:ncbi_taxonomy, true)
      if name.placement.nil? && (name.parent.nil? || name.parent == parent)
        placement.update(preferred: true)
      end
    end

    usage(t) unless args[:dir]
    ranks = Name.ranks.map(&:to_sym) + [:"no rank"]
    names = read_names_dmp(File.join(args[:dir], 'names.dmp'))
    nodes = read_nodes_dmp(File.join(args[:dir], 'nodes.dmp'))
    names = filter_names_by_domain(names, nodes, ranks)

    $stderr.puts 'Traversing names'
    Placement.update_all(ncbi_taxonomy: false)
    @n_name = 0
    i = 0
    names.each do |k, n|
      $stderr.print "\r- #{i += 1}/#{names.size} "
      name = find_or_create_name(n, nodes[k][1])
      register_name(k, name, names, nodes, ranks) if name.present?
    end
    $stderr.puts
    $stderr.puts "Names created: #{@n_name}"
    $stderr.puts "Reported placements: #{
      Placement.where(ncbi_taxonomy: true).count
    }"
  end

end
