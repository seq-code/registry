# app/serializers/name_serializer.rb
class NameSerializer
  include FastJsonapi::ObjectSerializer
  attributes :name, :rank, :status
  attribute :nomenclatural_type do |object|
    Services::Name::TypeResolver.resolve(object)
  end
end
