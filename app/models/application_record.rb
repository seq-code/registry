class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  has_many(
    :notified_notifications, class_name: 'Notification',
    as: :notifiable, dependent: :destroy
  )
  has_many(:linked_notifications, class_name: 'Notification',
    as: :linkeable, dependent: :nullify
  )
end
