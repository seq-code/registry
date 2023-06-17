
require 'miga'
require 'miga/cli'

namespace :genomes do
  desc 'Registers all genomes in a MiGA project to be evaluated'
  task :download => :environment do |t, args|
    def usage(t)
      puts "Usage: rake #{t}"
      exit 0
    end

    p_path = File.join(Rails.root, '..', 'miga_check')
    genomes = Genome.where(
      auto_check: false, auto_scheduled_at: nil, auto_failed: nil
    )

    $stderr.puts "Download genomes:"
    genomes.each do |genome|
      $stderr.puts "o #{genome.text} [#{genome.miga_name}]"
      MiGA::Cli.new([
        'get', '--project', p_path, '--dataset', genome.miga_name,
        '--universe', 'ncbi', '--db', genome.database,
        '--ids', genome.accession,
        '--type', (genome.kind_miga || 'popgenome')
      ]).launch(false)

      md = File.join(p_path, 'metadata', "#{genome.miga_name}.json")
      if File.exist?(md)
        genome.update(auto_scheduled_at: Time.now)
      else
        genome.update(
          auto_failed: "Cannot find ncbi:#{genome.database}:#{genome.accession}"
        )
      end
    end
  end

  desc 'Retrieves all genome data from a MiGA project'
  task :save, [:which] => :environment do |t, args|
    def usage(t)
      puts "Usage: rake #{t} or rake #{t}[all]"
      exit 0
    end
    
    p_path = File.join(Rails.root, '..', 'miga_check')
    p = MiGA::Project.load(p_path)
    genomes =
      case args[:which]
      when 'all'
        Genome.where.not(auto_scheduled_at: nil)
      when /^genome_(\d+)/
        Genome.where(id: $1)
      else
        Genome.where(auto_check: false).where.not(auto_scheduled_at: nil)
      end

    $stderr.puts "Save genomes:"
    genomes.each do |genome|
      $stderr.puts "o #{genome.text} [#{genome.miga_name}]"
      d = p.dataset(genome.miga_name) or next
      d.result(:stats) or next # Check if it's complete first

      assembly = d.result(:assembly).try(:stats)
      essential_genes = d.result(:essential_genes).try(:stats)
      ssu = d.result(:ssu).try(:stats)
      cds = d.result(:cds).try(:stats)

      new_data = {
        gc_content_auto: assembly.try(:dig, :g_c_content, 0),
        completeness_auto: essential_genes.try(:dig, :completeness, 0),
        contamination_auto: essential_genes.try(:dig, :contamination, 0),
        most_complete_16s_auto: ssu.try(:dig, :ssu_fragment, 0),
        number_of_16s_auto: ssu.try(:dig, :ssu),
        most_complete_23s_auto: ssu.try(:dig, :lsu_fragment, 0),
        number_of_23s_auto: ssu.try(:dig, :lsu),
        number_of_trnas_auto: ssu.try(:dig, :trna_aa),
        coding_density_auto: cds.try(:dig, :coding_density, 0),
        n50_auto: assembly.try(:dig, :n50, 0),
        contigs_auto: assembly.try(:dig, :contigs),
        assembly_length_auto: assembly.try(:dig, :total_length, 0),
        ambiguous_fraction_auto: assembly.try(:dig, :x_content, 0),
        codon_table_auto: cds.try(:dig, :codon_table)
      }
      genome.update(new_data.merge(auto_check: true))
    end
  end
end
