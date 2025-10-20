class Report < ApplicationRecord
  belongs_to :linkeable, polymorphic: true
  belongs_to :user, optional: true
end
