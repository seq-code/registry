class Version < ApplicationRecord
  belongs_to :record, polymorphic: true, optional: true
end
