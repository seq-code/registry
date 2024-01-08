json.(@subjects) do |subject|
  json.id(subject.id)
  json.value(subject.name)
  json.display(subject.name)
end

