class Tag < ApplicationRecord
  has_rich_text(:description)

  validates(:name, presence: true, uniqueness: true)
  validates(:color, presence: true)
end
