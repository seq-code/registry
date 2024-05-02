journal = journal.journal unless journal.is_a? String
json.name(journal)
json.url journal_url(journal, format: :json)
if @publications
  json.publications(
    @publications.map do |i|
      { id: i.id, citation: i.citation, doi: i.doi,
        url: publication_url(i, format: :json) }
    end
  )
end
