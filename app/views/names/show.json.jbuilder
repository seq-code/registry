json.response do
  json.status 'ok'
  json.message_type 'name'
end
json.partial! 'names/name', name: @name
