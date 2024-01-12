class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true
  belongs_to :linkeable, polymorphic: true, optional: true

  after_create do
    # Send email notification
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
end
