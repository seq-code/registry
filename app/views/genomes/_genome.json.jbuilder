json.extract!(
  genome, :id, :database, :accession, :kind, :seq_depth
)
json.sample(
  source_database: genome.source_database,
  source_accessions: genome.source_accessions
)
json.genomic_features(
  Hash[
    [[:seq_depth, genome.seq_depth]] +
      %w[
        gc_content most_complete_16s number_of_16s most_complete_23s
        number_of_23s number_of_trnas coding_density codon_table n50
        contigs largest_contig assembly_length ambiguous_fraction
      ].map { |i| [i, genome.send("#{i}_any")] }
  ]
)


json.auto_check(genome.auto_check)
json.created_at(genome.created_at)
json.updated_at(genome.updated_at)
json.url genome_url(genome, format: :json)
