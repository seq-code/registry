# Basic data
json.(name, :id, :name, :rank, :status_name)

# Local metadata
json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)
