class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  has_many(
    :notified_notifications, class_name: 'Notification',
    as: :notifiable, dependent: :destroy
  )
  has_many(:linked_notifications, class_name: 'Notification',
    as: :linkeable, dependent: :nullify
  )
  has_many(
    :reports, ->{ order(created_at: :desc) },
    as: :linkeable, dependent: :destroy
  )

  def qualified_id
    '%s:%i' % [self.class.to_s, id]
  end

  def notifications(user)
    notified_notifications.where(user: user).order(created_at: :desc)
  end
end
