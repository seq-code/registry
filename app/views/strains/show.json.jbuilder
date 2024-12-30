json.response do
  json.status 'ok'
  json.message_type 'strain'
end

json.extract!(@strain, :id)
json.strain_numbers(@strain.numbers)
json.url(strain_url(@strain, format: :json))
json.uri(@strain.uri)
json.typified_names(
  @strain.typified_names, partial: 'names/name_item', as: :name
)
if @strain.strain_info_data(false).present?
  json.strain_info_dois @strain.strain_info_data.map { |i| i[:strain][:doi] }
end
