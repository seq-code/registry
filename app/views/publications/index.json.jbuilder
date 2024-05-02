json.response do
  json.status 'ok'
  json.message_type 'publications'
  json.(@publications, :count, :current_page, :total_pages)
  json.next(
    @publications.next_page ?
      publications_url(format: :json, page: @publications.next_page) : nil
  )
end
json.values(
  @publications, partial: 'publications/publication', as: :publication
)
