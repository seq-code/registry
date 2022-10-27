json.(@names, :count, :current_page, :total_pages)
if @names.current_page < @names.total_pages
  json.next(names_url(
    sort: @sort, status: @status,
    page: @names.current_page + 1, format: :json
  ))
else
  json.next nil
end
json.values(@names, partial: 'names/name_ref', as: :name)
