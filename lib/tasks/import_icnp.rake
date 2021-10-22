
namespace :icnp do
  desc 'Imports ICNP names from an LTP-formatted TSV'
  task :import, [:tsv] => :environment do |t, args|
    def usage(t)
      puts "Usage: rake #{t}[ltp-classification.tsv]"
      exit 0
    end

    def save_taxonomy(str)
      node = nil
      str.split(';').each_with_index do |i, k|
        status = 20
        if k == 1 && i !~ /ota$/
          i = "#{i} (phylum)"
          status = 0
        end
        n = Name.find_by(name: i)
        n ||= Name.new(name: i)
        n.status = status
        n.parent = node
        n.rank =
          case k
            when 1 ; 'phylum'
            when 2 ; 'class'
            when 3 ; 'order'
            else ; n.inferred_rank
          end
        n.save or warn "Cannot save: #{i}: #{i.errors}"
        node = n
      end
      node
    end

    usage(t) unless args[:tsv]
    File.open(args[:tsv], 'r') do |fh|
      fh.each do |ln|
        next if $. == 1

        row = ln.chomp.split(/\t/).map { |i| i.sub(/^ */, '').sub(/ *$/, '') }
        puts "~ #{$.}: #{row[0]}"
        node = save_taxonomy(row[1])
        node = save_taxonomy(row[2]) if row[2]
        leaf = save_taxonomy(row[0])
        if leaf.rank == 'subspecies'
          sp = save_taxonomy(leaf.name.sub(/ subsp?\. .*/, ''))
          sp.update(parent: node)
          node = sp
        end
        leaf.update(parent: node)
      end
    end
  end

end
