json.response do
  json.status 'ok'
  json.message_type 'publication'
end
json.partial! 'publications/publication', publication: @publication
