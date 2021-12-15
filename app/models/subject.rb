class Subject < ApplicationRecord
  default_scope { order(name: :asc) }

  has_many(:publication_subjects, dependent: :destroy)
  has_many(:publications, through: :publication_subjects)
end
