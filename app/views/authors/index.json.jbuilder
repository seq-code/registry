json.response do
  json.status 'ok'
  json.message_type 'authors'
  json.(@authors, :count, :current_page, :total_pages)
  json.next(
    @authors.next_page ?
      authors_url(format: :json, page: @authors.next_page) : nil
  )
end
json.values(@authors, partial: 'authors/author', as: :author)
