# Basic data + nomenclature
json.(name, :id, :name, :rank, :status_name, :priority_date)
json.type_material do
  json.set!(name.type_material, name.type_accession)
  json.partial!('names/type_material', object: name.type_object)
end
json.classification(name.lineage, partial: 'names/name_ref', as: :name)

json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)

