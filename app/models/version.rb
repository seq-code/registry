class Version < ApplicationRecord
  belongs_to :record, polymorphic: true, optional: true
  # The record whose history includes this version, e.g. the name of a placement.
  belongs_to :owner, polymorphic: true, optional: true
  belongs_to :user, optional: true
end
