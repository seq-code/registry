module Versioned
  extend ActiveSupport::Concern

  included do
    has_many :versions, as: :record

    after_create :record_create_version
    after_update :record_update_version
    after_destroy :record_delete_version
  end

  private

  def record_create_version
    versions.create!(operation: 'create', changeset: {})
  end

  def record_update_version
    changeset = saved_changes.except('created_at', 'updated_at')
    versions.create!(operation: 'update', changeset: changeset) if changeset.any?
  end

  def record_delete_version
    Version.create!(record: self, operation: 'delete', changeset: {})
  end
end
