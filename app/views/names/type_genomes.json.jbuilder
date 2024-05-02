json.response do
  json.status 'ok'
  json.message_type 'type_genomes'
  json.(@names, :count, :current_page, :total_pages)
  json.next(
    @names.next_page ?
      name_type_genomes_url(format: :json, page: @names.next_page) : nil
  )
end
json.values(@names, partial: 'names/type_genome', as: :name)
