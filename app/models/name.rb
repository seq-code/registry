class Name < ApplicationRecord
  has_many :publication_names, dependent: :destroy
  has_many :publications, through: :publication_names
  belongs_to :proposed_by, optional: true,
    class_name: 'Publication', foreign_key: 'proposed_by'

  validates :name, presence: true, uniqueness: true
  validates :syllabication,
    format: {
      with: /\A[A-Z\.'-]*\z/i,
      message: 'Only letters, dashes, dots, and apostrophe are allowed'
    }

  class << self
    def etymology_particles
      %i[p1 p2 p3 p4 p5 xx]
    end

    def etymology_fields
      %i[lang grammar particle description]
    end
  end

  def abbr_name
    name.gsub(/^Candidatus /, '<i>Ca.</i> ').html_safe
  end

  def name_html
    name.gsub(/^Candidatus /, '<i>Candidatus</i> ').html_safe
  end

  def last_epithet
    name.gsub(/.* /, '')
  end

  def etymology(component, field)
    component = component.to_sym
    component = :xx if component == :full
    field = field.to_sym
    if component == :xx && field == :particle
      last_epithet
    else
      y = send(:"etymology_#{component}_#{field}")
      y.nil? || y.empty? ? nil : y
    end
  end

  def etymology?
    Name.etymology_particles.any? do |i|
      Name.etymology_fields.any? { |j| etymology(i, j) }
    end
  end

  def full_etymology(html = false)
    y = Name.etymology_particles.map do |component|
      partial_etymology(component, html)
    end.compact.join('; ')
    y.empty? ? nil : html ? y.html_safe : y
  end

  def partial_etymology(component, html = false)
    pre = [etymology(component, :lang), etymology(component, :grammar)].compact.join(' ')
    pre = nil if pre.empty?
    par = etymology(component, :particle)
    des = etymology(component, :description)
    if html
      pre = "<b>#{pre}</b>" if pre
      par = "<i>#{par}</i>" if par
    end
    y = [[pre, par].compact.join(' '), des].compact.join(', ')
    y.empty? ? nil : html ? y.html_safe : y
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
