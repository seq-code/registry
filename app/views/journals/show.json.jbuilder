json.response do
  json.status 'ok'
  json.message_type 'journal'
  json.(@publications, :count, :current_page, :total_pages)
  json.next(
    @publications.next_page ?
      journal_url(@journal, format: :json, page: @publications.next_page) : nil
  )
end
json.partial! 'journals/journal', journal: @journal
