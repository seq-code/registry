json.response do
  json.status 'ok'
  json.message_type 'register'
  json.(@names, :count, :current_page, :total_pages)
  json.next(
    @names.next_page ?
      register_url(@register, format: :json, page: @names.next_page) : nil
  )
end
json.partial! 'registers/register', register: @register
json.names(@names, partial: 'names/name_item', as: :name)
