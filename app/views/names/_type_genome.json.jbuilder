# Basic data + nomenclature
json.(name, :id, :name, :rank, :status_name, :priority_date)
json.type_material(
  name.type_material => name.type_accession
)
json.classification(name.lineage, partial: 'names/name_ref', as: :name)

json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)

