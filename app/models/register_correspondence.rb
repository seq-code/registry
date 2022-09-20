class RegisterCorrespondence < ApplicationRecord
  belongs_to(:register)
  belongs_to(:user)
  has_rich_text(:message)
end
