module Versioned
  extend ActiveSupport::Concern

  included do
    has_many :versions, as: :record
    class_attribute :versioned_owner_association
    class_attribute :versioned_attribute_sets, default: []
    class_attribute :always_versioned_attributes, default: []

    after_create :record_create_version
    after_update :record_update_version
    after_destroy :record_delete_version
  end

  class_methods do
    # Changing any member also records the other members' values, e.g. every
    # part of an etymology so each side can be read as a whole.
    def versioned_together(*attributes)
      self.versioned_attribute_sets = versioned_attribute_sets + [attributes.map(&:to_s)]
    end

    # Every version records these attributes, so each identifies what it is
    # about without its record, e.g. the publication of a publication link.
    def always_versioned(*attributes)
      self.always_versioned_attributes = always_versioned_attributes + attributes.map(&:to_s)
    end

    # Versions belong to the history of this association's record rather than
    # their own, e.g. a placement's versions are part of its name's history.
    def versioned_owner(association)
      self.versioned_owner_association = association
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
    record_version('create', versioned_attributes.transform_values { |value| [nil, value] })
  end

  # Always versioned attributes are added only once something else changed.
  def record_update_version
    changeset = versioned_changes
    return if changeset.empty?

    always_versioned = always_versioned_attributes.index_with do |attribute|
      [attribute_before_last_save(attribute), self[attribute]]
    end
    record_version('update', always_versioned.merge(changeset))
  end

  def record_delete_version
    record_version('delete', versioned_attributes.transform_values { |value| [value, nil] })
  end

  # Create directly rather than through versions, which is unavailable once the
  # record is destroyed.
  def record_version(operation, changeset)
    owner = versioned_owner_association ? public_send(versioned_owner_association) : self
    Version.create!(
      record: self, owner: owner, operation: operation, user: Current.user,
      changeset: changeset
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

    (self.class.versioned_attribute_sets + polymorphic_sets).each do |columns|
      next unless columns.intersect?(changeset.keys)

      (columns - changeset.keys).each do |column|
        values = [attribute_before_last_save(column), self[column]]
        changeset[column] = values unless values == [nil, nil]
      end
    end
    changeset
  end
end
