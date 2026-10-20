module Versioned
  extend ActiveSupport::Concern

  included do
    has_many :versions, as: :record
    class_attribute :versioned_attribute_sets, default: []

    after_create :record_create_version
    after_update :record_update_version
    after_destroy :record_delete_version
  end

  class_methods do
    # Changing any member records before/after values for every member.
    def versioned_together(*attributes)
      self.versioned_attribute_sets = versioned_attribute_sets + [attributes.map(&:to_s)]
    end
  end

  private

  def versioned_attributes
    attributes.transform_values { |value| versioned_value(value) }
  end

  def versioned_saved_changes
    saved_changes.transform_values { |values| values.map { |value| versioned_value(value) } }
  end

  # A rich text's body is a Content object; record its HTML.
  def versioned_value(value)
    value.is_a?(ActionText::Content) ? value.to_html.presence : value
  end

  def record_create_version
    versions.create!(operation: 'create', changeset: versioned_attributes.transform_values { |value| [nil, value] })
  end

  def record_update_version
    changeset = versioned_changes
    versions.create!(operation: 'update', changeset: changeset) if changeset.any?
  end

  def record_delete_version
    # The owner is already destroyed, so create directly rather than through
    # its association. Retain the final attributes and history.
    Version.create!(
      record: self, operation: 'delete',
      changeset: versioned_attributes.transform_values { |value| [value, nil] }
    )
  end

  # A changeset maps each changed attribute to [before, after], e.g.
  # { 'syllabication' => [nil, 'co.li'] } for E. coli.
  # Create and delete versions change every attribute from or to nothing,
  # retaining the full attributes: { 'rank' => [nil, 'species'] } on create and
  # { 'rank' => ['species', nil] } on delete.
  # Only update changesets omit timestamps.
  def versioned_changes
    changeset = versioned_saved_changes.except('created_at', 'updated_at')

    # A polymorphic ID is only meaningful together with its record type.
    polymorphic_sets = self.class.reflect_on_all_associations(:belongs_to)
                           .select(&:polymorphic?)
                           .map { |association| [association.foreign_key, association.foreign_type] }

    changed_columns = changeset.keys
    (self.class.versioned_attribute_sets + polymorphic_sets).each do |columns|
      changeset.merge!(versioned_together_changes(columns, changed_columns))
    end
    changeset
  end

  # If any listed column changed, include each member with a value as an
  # ordinary [before, after] pair, including unchanged columns such as language:
  # { 'etymology_xx_lang' => ['N.L.', 'N.L.'],
  #   'etymology_xx_description' => ['of the colon', 'from the colon'] }.
  def versioned_together_changes(columns, changed_columns)
    return {} if (changed_columns & columns).empty?

    columns.filter_map do |column|
      values = [attribute_before_last_save(column), self[column]]
      [column, values] unless values == [nil, nil]
    end.to_h
  end
end
