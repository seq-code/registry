class PublicationSubject < ApplicationRecord
  belongs_to :publication
  belongs_to :subject
end
