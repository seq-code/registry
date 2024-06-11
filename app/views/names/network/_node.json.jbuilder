json.(name, :id)
if %w[species subspecies].include? name.inferred_rank
  json.name(name.name.sub(/^((Ca)ndidatus )?([A-Z])[a-z]+ /, '\2\3. '))
else
  json.name(name.name.sub(/^((Ca)ndidatus )?/, '\2'))
end
json.styling(name.name_html)
json.url(name_url(name))
json.rank(name.inferred_rank)

