json.response do
  json.status 'ok'
  json.message_type 'names'
  json.(@names, :count, :current_page, :total_pages)
  json.next(
    @names.next_page ?
      names_url(format: :json, status: @status, page: @names.next_page) : nil
  )
end
json.values(@names, partial: 'names/name_item', as: :name)
