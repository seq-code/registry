# Basic data + nomenclature
json.(name, :id, :name, :rank, :status_name, :syllabication)
unless name.description.empty?
  json.description(
    raw: name.description.body.to_plain_text, html: name.description.body
  )
end
json.formal_styling(raw: strip_tags(name.formal_html), html: name.formal_html)
json.etymology(name.full_etymology(false))
json.type(name.type_is_name? ? name.type_name.name : name.type_text)

unless name.notes.empty?
  json.notes(raw: name.notes.body.to_plain_text, html: name.notes.body)
end
if name.proposed_by
  json.proposed_by(
    id: name.proposed_by.id,
    citation: name.proposed_by.citation,
    url: publication_url(name.proposed_by, format: :json)
  )
end
if name.corrigendum_by
  json.corrigendum_by(
    id: name.corrigendum_by.id,
    citation: name.corrigendum_by.citation,
    url: publication_url(name.corrigendum_by, format: :json)
  )
  json.(name, :corrigendum_from)
end

# Taxonomy
json.parent(id: name.parent.id, name: name.parent.name) if name.parent
json.children(name.children) { |child| json.(child, :id, :name) }

# QC Warnings
json.qc_warnings(
  name.qc_warnings.map do |i|
    i.select { |k, _| !%i[link_to link_text].include? k }
  end
)

# Local metadata
json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)

