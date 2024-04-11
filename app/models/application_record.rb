class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  has_many(
    :notified_notifications, class_name: 'Notification',
    as: :notifiable, dependent: :destroy
  )
  has_many(:linked_notifications, class_name: 'Notification',
    as: :linkeable, dependent: :nullify
  )

  def notifications(user)
    notified_notifications.where(user: user).order(created_at: :desc)
  end
end
