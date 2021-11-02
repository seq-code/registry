json.extract! register, :id, :accession, :user_id, :validated_by, :submitted, :validated, :publication_id, :publication_pdf, :supplementary_pdf, :record_pdf, :created_at, :updated_at
json.url register_url(register, format: :json)
json.publication_pdf url_for(register.publication_pdf)
json.supplementary_pdf url_for(register.supplementary_pdf)
json.record_pdf url_for(register.record_pdf)
