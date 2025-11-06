class Author < ApplicationRecord
  has_many(:publication_authors, dependent: :destroy)
  has_many(:publications, through: :publication_authors)
  has_many(:publication_names, through: :publications)
  has_many(:names, -> { group(:name_id) }, through: :publication_names)
  has_many(:contacts)

  class << self
    def find_or_create(given, family)
      par = {
        given: standardize_given(given),
        family: standardize_family(family)
      }
      author = where(par).first
      author ||= Author.new(par).tap(&:save)
    end

    def standardize_given(given)
      if given.to_s.match(/\A[A-Z]( [A-Z])* ?\z/)
        given.to_s.gsub(/( | ?$)/, '. ').gsub(/ $/, '')
      else
        standardize_family(given)
      end
    end

    def standardize_family(family)
      family == family.to_s.upcase ? family.titlecase : family
    end
  end

  def full_name
    family.to_s + ( given ? ", #{given}" : '' )
  end

  def abbreviated_name
    family.to_s + ( given ? ' ' + given.gsub(/([^\s])[^\s]+ ?/, '\1') : '' )
  end

  def standard_name?
    family == self.class.standardized_family(family) &&
      given == self.class.standardized_given(given)
  end
end
