class Author < ApplicationRecord
  has_many :publication_authors, dependent: :destroy
  has_many :publications, through: :publication_authors

  def full_name
    family + ( given ? ", #{given}" : '' )
  end
end
