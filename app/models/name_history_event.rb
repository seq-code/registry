class NameHistoryEvent < ApplicationRecord
  # Events retain their owner ID and data even after the name is deleted.
  belongs_to :name, optional: true

  validates :kind, inclusion: {
    in: %w[attributes_changed publication_linked publication_unlinked]
  }
end
