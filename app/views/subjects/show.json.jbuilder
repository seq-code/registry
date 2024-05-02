json.response do
  json.status 'ok'
  json.message_type 'subject'
  json.(@publications, :count, :current_page, :total_pages)
  json.next(
    @publications.next_page ? 
      subject_url(@subject, format: :json, page: @publications.next_page) : nil
  )
end
json.partial! 'subjects/subject', subject: @subject
