class Tutorial < ApplicationRecord
  belongs_to(:user)
  has_many(:names, dependent: :nullify)
end
