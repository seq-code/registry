json.response do
  json.status 'ok'
  json.message_type 'syllabify'
end
json.syllabification(@syllabification)
json.(@name, :last_epithet)
