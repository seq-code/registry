json.extract! genome, :id, :database, :accession, :type, :gc_content, :completeness, :contamination, :seq_depth, :most_complete_16s, :number_of_16s, :most_complete_23s, :number_of_23s, :number_of_trnas, :updated_by, :auto_check, :created_at, :updated_at
json.url genome_url(genome, format: :json)
