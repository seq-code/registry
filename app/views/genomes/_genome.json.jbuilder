json.partial!('/genomes/genome_item', genome: genome)
json.sample(genome, :source_database, :source_accessions)
json.genomic_features(
  Hash[
    [[:auto_check, genome.auto_check], [:seq_depth, genome.seq_depth]] +
      %w[
        gc_content most_complete_16s number_of_16s most_complete_23s
        number_of_23s number_of_trnas coding_density codon_table n50
        contigs largest_contig assembly_length ambiguous_fraction
      ].map { |i| [i, genome.send("#{i}_any")] }
  ]
)
json.names(
  genome.names.map do |i|
    { id: i.id, name: i.name, url: name_url(i, format: :json) }
  end
)
json.strain(@genome.strain, partial: 'strains/strain_item', as: :strain)
json.created_at(genome.created_at)
json.updated_at(genome.updated_at)
