json.class(object ? object.class.to_s : 'unknown')
json.id(object.try(:id))
unless object.is_a?(Strain)
  json.url(object ? polymorphic_url(object, format: :json) : nil)
end
json.uri object.try(:uri)
json.display(object.try(:display, false))
