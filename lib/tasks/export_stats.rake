
namespace :stats do
  desc 'Exports name statistics in tab-delimited format'
  task :export, [:output] => :environment do |t, args|
    def usage(t)
      puts "Usage: rake #{t}[seqcode-stats.tsv]"
      exit 0
    end

    usage(t) unless args[:output]

    # Collecting genomes
    File.open(args[:output], 'w') do |fh|
      fh.puts %w[year rank submitted endorsed validly_published].join("\t")
      (2022 .. DateTime.now.year).each do |year|
        date_from  = DateTime.parse("1-1-#{year}")
        date_to    = DateTime.parse("1-1-#{year + 1}")
        date_range = date_from .. date_to

        Name.ranks.each do |rank|
          # Status
          # - 10: submitted
          # - 12: endorsed
          # - 15: validly published under the SeqCode
          s = Name.where('status >= 10').where.not(submitted_at: nil)
                  .where(rank: rank, submitted_at: date_range)
                  .count
          e = Name.where('status >= 12').where.not(endorsed_at: nil)
                  .where(rank: rank, submitted_at: date_range)
                  .count
          v = Name.where(status: 15)
                  .where(rank: rank, validated_at: date_range)
                  .count

          fh.puts [year, rank, s, e, v].join("\t")
        end
      end
    end
  end
end

