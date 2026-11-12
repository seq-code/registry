module Versioned
  extend ActiveSupport::Concern

  included do
    has_many :versions, as: :record
    class_attribute :versioned_attribute_sets, default: []
    class_attribute :versioned_owner_association
    class_attribute :always_versioned_attributes, default: []
    class_attribute :versioned_never_attributes, default: %w[created_at updated_at]

    after_create :record_create_version
    after_update :record_update_version
    after_destroy :record_delete_version
  end

  class_methods do
    # Changing any member records before/after values for every member.
    def versioned_together(*attributes)
      self.versioned_attribute_sets = versioned_attribute_sets + [attributes.map(&:to_s)]
    end

    # Every version records these attributes, so each identifies what it is
    # about without its record, e.g. the publication of a publication link.
    def always_versioned(*attributes)
      self.always_versioned_attributes = always_versioned_attributes + attributes.map(&:to_s)
    end

    # Changes to these attributes alone add no version, and update versions
    # omit them, e.g. cached responses from external services.
    def versioned_never(*attributes)
      self.versioned_never_attributes = versioned_never_attributes + attributes.map(&:to_s)
    end

    # Versions belong to the history of this association's record rather than
    # their own, e.g. a placement's versions are part of its name's history.
    def versioned_owner(association)
      self.versioned_owner_association = association
    end
  end

  private

  # Every attribute's current value, e.g. { 'rank' => 'species', ... }.
  # Create and delete versions record this full snapshot as the after or
  # before side of each pair.
  def versioned_attributes
    attributes.transform_values { |value| versioned_value(value) }
  end

  # The attributes changed by the save that just happened, as Rails'
  # saved_changes reports them: { 'rank' => ['genus', 'species'] }.
  # Update versions start from this. Like versioned_attributes, it converts
  # values that cannot be stored in the changeset as they are.
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
  # Only update changesets omit timestamps and never versioned attributes.
  def versioned_changes
    changeset = versioned_saved_changes.except(*versioned_never_attributes)

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
