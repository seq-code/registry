json.(@names, :count, :current_page, :total_pages)
if @names.current_page < @names.total_pages
  json.next name_type_genomes_url(page: @names.current_page + 1, format: :json)
else
  json.next nil
end
json.values(@names, partial: 'names/type_genome', as: :name)

