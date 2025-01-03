json.response do
  json.status 'ok'
  json.message_type 'strain'
end

json.partial!('strains/strain_item', strain: @strain)
json.typified_names(
  @strain.typified_names, partial: 'names/name_item', as: :name
)
json.genomes(@strain.genomes, partial: 'genomes/genome_item', as: :genome)
if @strain.strain_info_data(false).present?
  json.strain_info_dois @strain.strain_info_data.map { |i| i[:strain][:doi] }
end

