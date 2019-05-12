class Publication < ApplicationRecord
  default_scope { order(journal_date: :desc) }
  
  has_many :publication_authors, dependent: :destroy
  has_many :publication_subjects, dependent: :destroy
  has_many :publication_names, dependent: :destroy
  has_many :authors, -> { order('publication_authors.id ASC') },
    through: :publication_authors
  has_many :subjects, through: :publication_subjects
  has_many :names, through: :publication_names

  def authors_et_al
    if authors.count < 3
      authors.pluck(:family).join(', ')
    else
      authors.pluck(:family).first + ', et al'
    end
  end

  def clean_abstract
    abstract.gsub(/<[^>]+>/, '') if abstract
  end

  def short_citation
    "#{authors_et_al} (#{journal_date.year})"
  end

  def citation
    "#{short_citation}, #{journal || pub_type.tr('-', ' ')}"
  end
end
