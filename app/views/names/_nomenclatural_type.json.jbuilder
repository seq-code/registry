json.class(object ? object.class.to_s : 'unknown')
json.id(object.try(:id))
# TODO
# Define strain URLs
json.url(
  object && !object.is_a?(Strain) ? polymorphic_url(object, format: :json) : nil
)
json.uri object.try(:uri)
json.display(object.try(:display, false))
