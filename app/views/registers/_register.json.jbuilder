json.extract! register, :accession, :validated_by, :submitted, :validated, :publication_id, :created_at, :updated_at
json.acc_url register.acc_url(true)
json.url register_url(register, format: :json)
#json.publication_pdf url_for(register.publication_pdf)
#json.supplementary_pdf url_for(register.supplementary_pdf)
#json.record_pdf url_for(register.record_pdf)
