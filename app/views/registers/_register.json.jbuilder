json.extract!(
  register, :acc_url, :title, :submitted, :validated,
  :created_at, :updated_at, :priority_date
)
json.validated_by register.validated_by&.display_name
json.submitter register.user&.display_name
if register.publication_id
  json.effective_publication(
    id: register.publication_id,
    url: publication_url(register.publication_id, format: :json)
  )
else
  json.effective_publication(nil)
end
if register.validated?
  json.doi(register.propose_doi)
end
json.url register_url(register, format: :json)
