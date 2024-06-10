if placement.is_a? Placement
  json.source placement.name.id
  json.target placement.parent.id
  json.preferred placement.preferred
  json.gtdb_taxonomy placement.gtdb_taxonomy
  json.ncbi_taxonomy placement.ncbi_taxonomy
else
  json.source placement[:source]
  json.target placement[:target]
  json.kind placement[:kind]
end
