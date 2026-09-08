json.(@names) do |name|
  json.id(name.id)
  json.value(name.name)
  json.rank(name.inferred_rank)
  json.display(
    safe_join(
      [name.display, tag.small(name.inferred_rank, class: 'text-muted')], ' '
    )
  )
end
