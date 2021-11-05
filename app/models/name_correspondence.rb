class NameCorrespondence < ApplicationRecord
  belongs_to :name
  belongs_to :user
  has_rich_text :message
end
