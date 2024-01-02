class RegisterCorrespondence < ApplicationRecord
  belongs_to(:register)
  belongs_to(:user)
  has_rich_text(:message)
  attr_accessor :notify
  after_create(:notify_observers)

  def notify_observers
    return unless notify == '1'
    register.notify_observers(:correspondence, exclude_users: [user])
  end
end
