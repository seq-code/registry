json.response do
  json.status 'ok'
  json.message_type 'author'
  json.(@publications, :count, :current_page, :total_pages)
  json.next(
    @publications.next_page ?
      author_url(@author, format: :json, page: @publications.next_page) : nil
  )
end
json.partial! 'authors/author', author: @author
