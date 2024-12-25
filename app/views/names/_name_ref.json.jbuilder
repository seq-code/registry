# Basic data
json.(name, :id, :name, :rank, :status_name, :priority_date)
json.nomenclatural_type do
  json.partial!('names/nomenclatural_type', object: name.nomenclatural_type)
end

# Local metadata
json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)
json.uri name.seqcode_url
