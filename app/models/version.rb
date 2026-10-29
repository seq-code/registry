class Version < ApplicationRecord
  # Historical records remain accessible when their model retains soft-deleted rows.
  belongs_to :record, -> { respond_to?(:with_deleted) ? with_deleted : all },
             polymorphic: true, optional: true
  belongs_to :user, optional: true
end
