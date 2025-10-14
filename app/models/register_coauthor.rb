class RegisterCoauthor < ApplicationRecord
  belongs_to(:register)
  belongs_to(:user)
  validates(:order, presence: true)
end
