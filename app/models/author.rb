class Author < ApplicationRecord
  has_many(:publication_authors, dependent: :destroy)
  has_many(:publications, through: :publication_authors)
  has_many(:publication_names, through: :publications)
  has_many(:names, -> { group(:name_id) }, through: :publication_names)

  class << self
    def find_or_create(given, family)
      par = { given: given, family: family }
      author = where(par).first
      author ||= Author.new(par).tap(&:save)
    end
  end

  def full_name
    family.to_s + ( given ? ", #{given}" : '' )
  end

  def abbreviated_name
    family.to_s + ( given ? ' ' + given.gsub(/([^\s])[^\s]+ ?/, '\1') : '' )
  end
end
