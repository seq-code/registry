json.extract! subject, :id, :name
json.url subject_url(subject, format: :json)
json.extract! subject, :created_at, :updated_at
json.publications(
  @publications.map do |i|
    { citation: i.citation, doi: i.doi, url: publication_url(i, format: :json) }
  end
) if @publications
