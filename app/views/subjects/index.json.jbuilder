json.response do
  json.status 'ok'
  json.message_type 'subjects'
  json.(@subjects, :count, :current_page, :total_pages)
  json.next(
    @subjects.next_page ?
      subjects_url(format: :json, page: @subjects.next_page) : nil
  )
end
json.values(@subjects, partial: 'subjects/subject_item', as: :subject)
