class Name < ApplicationRecord
  default_scope { order(name: :asc) }
  
  has_many :publication_names, dependent: :destroy
  has_many :publications, through: :publication_names

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
end
