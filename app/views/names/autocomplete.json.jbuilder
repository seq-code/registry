json.(@names) do |name|
  json.id(name.id)
  json.value(name.name)
  json.display(name.display)
end
