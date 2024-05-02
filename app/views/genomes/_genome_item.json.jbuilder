json.extract!(
  genome, :id, :database, :accession, :kind
)
json.url genome_url(genome, format: :json)
json.uri genome.uri
