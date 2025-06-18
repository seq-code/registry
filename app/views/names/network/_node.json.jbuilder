if name.is_a? Name
  json.(name, :id)
  json.is_name(true)
  if %w[species subspecies].include? name.inferred_rank
    json.name(name.name.sub(/^((Ca)ndidatus( ))?([A-Z])[a-z]+ /, '\2\3\4. '))
  else
    json.name(name.name.sub(/^((Ca)ndidatus( ))?/, '\2\3'))
  end
  json.styling(name.name_html)
  json.url(name_url(name))
  json.rank(name.inferred_rank)
  json.valid(name.validated?)
  json.status_code(name.status_hash[:symbol])
  json.illegitimate(name.illegitimate?)
else
  json.id(name.qualified_id)
  json.is_name(false)
  json.name(name.title)
  json.styling(name.title)
  json.url(polymorphic_url(name))
  json.rank('subspecies')
  json.valid(false)
  json.status_code(nil)
  json.illegitimate(false)
end
