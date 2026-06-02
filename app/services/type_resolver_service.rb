# frozen_string_literal: true

# Service object to resolve the nomenclatural type for a name.
# This encapsulates the logic for determining the type_of_type value
# and handling edge cases.
class TypeResolverService
  # Resolves the nomenclatural type class for a given object.
  # @param object [Object, nil] The object to resolve (e.g., a Name, Genome, or Strain).
  # @return [String] The resolved type_of_type value, or 'unknown' if unresolved.
  def self.resolve(object)
    return 'unknown' if object.nil?
    return object.type_of_type if object.respond_to?(:type_of_type)
    'unknown'
  end

  # Resolves the nomenclatural type class for a given object, with additional context.
  # @param object [Object, nil] The object to resolve.
  # @param context [Hash] Additional context (e.g., { fallback: 'Name' }).
  # @return [String] The resolved type_of_type value.
  def self.resolve_with_context(object, context = {})
    resolved = resolve(object)
    return resolved unless resolved == 'unknown' && context[:fallback].present?
    context[:fallback]
  end
end
