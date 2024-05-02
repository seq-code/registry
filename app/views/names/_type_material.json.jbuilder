json.class(object ? object.class.to_s : 'unknown')
json.id(object.try(:id))
json.url(object ? polymorphic_url(object, format: :json) : nil)
json.display(object.try(:display, false))
