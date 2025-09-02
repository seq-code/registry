class Check < ApplicationRecord
  belongs_to(:name)
  belongs_to(:user, optional: true)

  def fail?
    !pass?
  end
end
