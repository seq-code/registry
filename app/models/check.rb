class Check < ApplicationRecord
  belongs_to(:name)
  belongs_to(:user)

  def fail?
    !pass?
  end
end
