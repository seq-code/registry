json.response do
  json.status 'ok'
  json.message_type 'registers'
  json.(@registers, :count, :current_page, :total_pages)
  json.next(
    @registers.next_page ?
      registers_url(
        format: :json, status: @status, page: @registers.next_page
      ) : nil
  )
end
json.values(@registers, partial: 'registers/register_item', as: :register)
