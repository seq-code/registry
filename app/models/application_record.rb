class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # has_many(:notified_notifications, as: :linkeable, dependent: :destroy)
  # has_many(:linked_notifications, as: :linkeable, dependent: :nullify)
end
