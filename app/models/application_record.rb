class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  has_many(:notifications, as: :linkeable, dependent: :destroy)
end
