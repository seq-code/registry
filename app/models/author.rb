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
      case given.to_s
      when /\A\p{Lu}\z/
        # A single uppercase letter
        given + '.'
      when /\A.{0,3}\z/
        # Too short to tell, it could be initials
        given
      when /\A\p{Lu}( \p{Lu})* ?\z/
        # Initials separated by spaces
        given.gsub(/( | ?$)/, '. ').gsub(/ $/, '')
      when /\A(\p{Lu}\.)+\z/
        # Initials separated by dots
        given.gsub(/\./, '. ').gsub(/ $/, '')
      else
        # Treat as a full name
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
    family == self.class.standardize_family(family) &&
      given == self.class.standardize_given(given)
  end
end
