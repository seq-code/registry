json.partial!('registers/register_item', register: register)
json.extract!(register, :submitted, :validated)
json.validated_by register.validated_by.try(:display_name)
json.submitter register.user.try(:display_name)
json.effective_publication do
  register.publication_id ?
    json.partial!(
      'publications/publication_item', publication: register.publication
    ) : nil
end
json.doi(register.propose_doi) if register.validated?
json.extract!(register, :created_at, :updated_at)
