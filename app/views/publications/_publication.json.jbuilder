json.extract! publication, :id, :title, :journal, :journal_loc, :journal_date, :doi, :url, :pub_type, :crossref_json, :abstract, :created_at, :updated_at
json.url publication_url(publication, format: :json)
