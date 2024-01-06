# Basic data + nomenclature
json.(name, :id, :name, :rank, :status_name, :syllabication, :priority_date)
unless name.description.empty?
  json.description(
    raw: name.description.body.to_plain_text, html: name.description.body
  )
end
json.formal_styling(raw: name.formal_txt, html: name.formal_html)
json.etymology(name.full_etymology(false))
json.type(name.type_is_name? ? name.type_name.name : name.type_text)

unless name.notes.empty?
  json.notes(raw: name.notes.body.to_plain_text, html: name.notes.body)
end
if name.proposed_in
  json.proposed_in(
    id: name.proposed_in.id,
    citation: name.proposed_in.citation,
    url: publication_url(name.proposed_in, format: :json)
  )
end
if name.corrigendum_in
  json.corrigendum_in(
    id: name.corrigendum_in.id,
    citation: name.corrigendum_in.citation,
    url: publication_url(name.corrigendum_in, format: :json)
  )
  json.(name, :corrigendum_from)
end
if name.assigned_in
  json.assigned_in(
    id: name.assigned_in.id,
    citation: name.assigned_in.citation,
    url: publication_url(name.assigned_in, format: :json)
  )
end
if name.emended_in.present?
  json.emended_in(
    name.emended_in.map do |pub|
      {
        id: pub.id,
        citation: pub.citation,
        url: publication_url(pub, format: :json)
      }
    end
  )
end

# Taxonomy
if name.parent
  json.classification(name.lineage, partial: 'names/name_ref', as: :name)
end
json.children(name.children) { |child| json.(child, :id, :name) }

# Register list
if name.status == 15
  json.register(
    acc: name.register.acc_url,
    doi: name.register.propose_doi,
    url: register_url(name.register, format: :json)
  )
end

# QC Warnings
unless name.validated?
  json.qc_warnings(name.qc_warnings.map(&:to_hash))
end

# Local metadata
json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)
