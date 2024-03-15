# Basic data + nomenclature
json.(name, :id, :name, :rank, :status_name, :priority_date)
json.type_material(
  name.type_material => name.type_accession,
  class: name.type_object ? name.type_object.class.to_s : 'unknown',
  url: name.type_object ?
        polymorphic_url(name.type_object, format: :json) : nil,
  display: name.type_object&.display(false),
)
json.classification(name.lineage, partial: 'names/name_ref', as: :name)

json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)

