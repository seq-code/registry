json.(@publications) do |publication|
  json.id(publication.id)
  json.value(publication.doi_title(false))
  json.display(publication.doi_title(true))
end
