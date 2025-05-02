class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true
  belongs_to :linkeable, polymorphic: true, optional: true

  after_create(:send_email_notification)
  after_create(:broadcast_web_notification)
  after_save(:broadcast_notification_count)

  private

  def send_email_notification
    mail = AdminMailer.with(
      user: user,
      object: notifiable,
      action: action
    ).templated_email

    if mail # Unless user has turned this email notification off
      mail.deliver_later
      update(notified_email: true)
    end
  end

  def broadcast_web_notification
    WebNotificationsChannel.broadcast_to(
      user,
      title: title || action,
      tag: notifiable,
      alert: id
    )
  end

  def broadcast_notification_count
    NotificationCountsChannel.broadcast_to(
      user, count: user.unseen_notifications.count
    )
  end
end
