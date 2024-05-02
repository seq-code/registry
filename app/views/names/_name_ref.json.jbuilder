# Basic data
json.(name, :id, :name, :rank, :status_name, :priority_date)
json.type_material do
  json.partial!('names/type_material', object: name.type_object)
end

# Local metadata
json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)
json.uri name.seqcode_url
