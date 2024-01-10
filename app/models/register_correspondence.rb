class RegisterCorrespondence < ApplicationRecord
  belongs_to(:register)
  belongs_to(:user)
  has_rich_text(:message)
  has_many(:notifications, as: :notifiable, dependent: :destroy)

  attr_accessor :notify

  after_create(:notify_observers)

  def obj
    register
  end

  def notify_observers
    return unless notify == '1'
    register.notify_observers(:correspondence, exclude_users: [user])
  end
end
