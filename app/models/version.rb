class Version < ApplicationRecord
  belongs_to :record, polymorphic: true, optional: true
  belongs_to :user, optional: true
end
