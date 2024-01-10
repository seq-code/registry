class NameCorrespondence < ApplicationRecord
  belongs_to(:name)
  belongs_to(:user)
  has_rich_text(:message)
  has_many(:notifications, as: :notifiable)

  attr_accessor :notify

  after_create(:notify_observers)

  def obj
    name
  end

  def notify_observers
    return unless notify == '1'
    name.notify_observers(:correspondence, exclude_users: [user])
  end
end
