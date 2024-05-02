json.(@authors) do |author|
  json.id(author.id)
  json.value(author.full_name)
  json.display(name.full_name)
end
