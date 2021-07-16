# Basic data + nomenclature
json.(name, :id, :name, :rank, :syllabication)
unless name.description.empty?
  json.description(
    raw: name.description.body.to_plain_text, html: name.description.body
  )
end
unless name.notes.empty?
  json.notes(raw: name.notes.body.to_plain_text, html: name.notes.body)
end
if name.proposed_by
  json.proposed_by(id: name.proposed_by.id, citation: name.proposed_by.citation)
end
if name.corrigendum_by
  json.corrigendum_by publication_url(name.corrigendum_by, format: :json)
  json.(name, :corrigendum_from)
end
json.formal_styling(raw: strip_tags(name.formal_html), html: name.formal_html)

# Taxonomy
json.parent(id: name.parent.id, name: name.parent.name) if name.parent
json.children(name.children) { |child| json.(child, :id, :name) }

# Local metadata
json.(name, :created_at, :updated_at)
json.url name_url(name, format: :json)

