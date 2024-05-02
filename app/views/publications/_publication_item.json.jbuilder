json.extract!(publication, :id, :citation, :doi)
json.url publication_url(publication, format: :json)
