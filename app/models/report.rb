class Report < ApplicationRecord
  belongs_to :linkeable, polymorphic: true
end
