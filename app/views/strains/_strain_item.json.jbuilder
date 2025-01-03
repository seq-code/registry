json.extract!(strain, :id)
json.strain_numbers(strain.numbers)
json.url(strain_url(strain, format: :json))
json.uri(strain.uri)
