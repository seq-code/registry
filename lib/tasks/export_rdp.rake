
namespace :rdp do
  desc 'Exports 16S sequences from type genomes for RDP'
  task :export, [:output] => :environment do |t, args|
    def usage(t)
      puts "Usage: rake #{t}[seqcode-rdp]"
      exit 0
    end

    usage(t) unless args[:output]
    dir = File.absolute_path(args[:output])
    tsv = dir + '.tsv'
    tgz = dir + '.tar.gz'

    # Collecting genomes
    $stderr.puts "-> #{tsv}"
    genomes = []
    File.open(tsv, 'w') do |fh|
      Name.where(status: 15, rank: :species).each do |name|
        next unless name.genome # <- This should never happen in production!
        $stderr.puts '~ ' + name.name
        genome = "genome_#{name.genome.id}"
        genomes << genome
        fh.puts [
          name.lineage.map { |i| "#{i.rank}: #{i.name}" }.join('; '),
          name.name, genome
        ].join("\t")
      end
    end

    # Extracting sequences
    $stderr.puts "-> #{dir}"
    FileUtils.rm_rf(dir)
    FileUtils.mkdir_p(dir)
    project = File.join(Rails.root, '..', 'miga_check')
    ssu = File.join(project, 'data', '07.annotation', '01.function', '02.ssu')
    genomes.each do |genome|
      file = "#{genome}.ssu.all.fa.gz"
      from = File.join(ssu, file)
      to = File.join(dir, file)
      next unless File.exist?(from)

      FileUtils.cp(from, to)
      `gunzip "#{to}"`
    end

    # Packaging
    $stderr.puts "-> #{tgz}"
    base = File.basename(dir)
    `cd "#{dir}/.." && tar -zcf "#{base}.tar.gz" "#{base}.tsv" "#{base}"`
    FileUtils.rm_rf([tsv, dir])
  end

end
