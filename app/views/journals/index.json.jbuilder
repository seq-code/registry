json.response do
  json.status 'ok'
  json.message_type 'journals'
  json.(@journals, :count, :current_page, :total_pages)
  json.next(
    @journals.next_page ?
      journals_url(format: :json, page: @journals.next_page) : nil
  )
end
json.values(@journals, partial: 'journals/journal', as: :journal)
