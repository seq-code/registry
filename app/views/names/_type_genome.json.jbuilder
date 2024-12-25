# Basic data + nomenclature
json.(name, :id, :name, :rank, :status_name, :priority_date)
json.nomenclatural_type do
  json.set!(name.type_genome.database, name.type_genome.accession)
  json.partial!('names/nomenclatural_type', object: name.nomenclatural_type)
end
json.classification(name.lineage, partial: 'names/name_ref', as: :name)

json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)
