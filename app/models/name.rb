class Name < ApplicationRecord
  has_many :publication_names, dependent: :destroy
  has_many :publications, through: :publication_names
  belongs_to :proposed_by, optional: true,
    class_name: 'Publication', foreign_key: 'proposed_by'

  validates :name, presence: true, uniqueness: true

  def abbr_name
    name.gsub(/^Candidatus /, '<i>Ca.</i> ').html_safe
  end

  def name_html
    name.gsub(/^Candidatus /, '<i>Candidatus</i> ').html_safe
  end

  def ncbi_search_url
    "https://www.ncbi.nlm.nih.gov/nuccore/?term=%22#{name.tr(' ', '+')}%22"
  end

  def proposed_by?(publication)
    publication == proposed_by
  end

  def emended_by
    publication_names.where(emends: true).map(&:publication)
  end

  def emended_by?(publication)
    emended_by.include? publication
  end
end
