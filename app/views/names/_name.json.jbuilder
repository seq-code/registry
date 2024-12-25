json.partial!('names/name_item', name: name)

# Nomenclature
json.(name, :rank, :status_name, :syllabication, :priority_date)
unless name.description.empty?
  json.description(
    raw: name.description.body.to_plain_text, html: name.description.body
  )
end
json.formal_styling(raw: name.formal_txt, html: name.formal_html)
json.etymology(name.full_etymology(false))
json.nomenclatural_type do
  json.partial!('names/nomenclatural_type', object: name.nomenclatural_type)
end
unless name.notes.empty?
  json.notes(raw: name.notes.body.to_plain_text, html: name.notes.body)
end
json.proposed_in do
  json.partial!(
    'publications/publication_item', publication: name.proposed_in
  )
end if name.proposed_in
json.not_validly_proposed_in(
  name.not_validly_proposed_in, partial: 'publications/publication_item',
  as: :publication
) if name.not_validly_proposed_in.present?
if name.corrigendum_in
  json.corrigendum_in do
    json.partial!(
      'publications/publication_item', publication: name.corrigendum_in
    )
  end
  json.(name, :corrigendum_from)
end
json.assigned_in do
  json.partial!('publications/publication_item', publication: name.assigned_in)
end if name.assigned_in
json.emended_in(
  name.emended_in, partial: 'publications/publication_item', as: :publication
) if name.emended_in.present?

# Taxonomy
json.classification(name.lineage, partial: 'names/name_ref', as: :name)
json.children(name.children, partial: 'names/name_item', as: :name)

# Register list
if name.status == 15
  json.register(
    name.register, partial: 'registers/register_item', as: :register
  )
end

# QC Warnings
unless name.validated?
  json.qc_warnings(name.qc_warnings.map(&:to_hash))
end

# Local metadata
json.(name, :created_at, :updated_at)
