json.extract! author, :id, :given, :family, :created_at, :updated_at
json.publications(
  @publications.map do |i|
    { id: i.id, citation: i.citation, doi: i.doi,
      url: publication_url(i, format: :json) }
  end
) if @publications
json.url author_url(author, format: :json)
