class Strain < ApplicationRecord
  has_many(:genomes, dependent: :nullify)
  has_many(:name_paratypes, as: :nomenclatural_type, dependent: :destroy)
  has_many(:paratypified_names, through: :name_paratypes, source: :name)

  validates(:numbers_string, presence: true)

  before_save(:clean_numbers)

  include HasExternalResources
  include Strain::ExternalResources
  include TypeMaterial

  class << self
    def all_public
      where(typified_names: Name.all_public)
    end
  end

  def numbers
    numbers_string.split(' = ')
  end

  def numbers_parsed
    @numbers_parsed ||= StrainCode.parse(numbers_string)
  end

  def collections
    numbers_parsed.map(&:catalogue).compact.uniq
  end

  def type_of_type
    'Strain'
  end

  def display(_html = true)
    "#{type_of_type}: #{numbers_string}"
  end

  def old_type_definition
    ['strain', numbers_string]
  end

  def title(prefix = nil, html: true, sup: true)
    prefix ||= 'Strain '
    y = '%ssc|%07i' % [prefix, id]
    if sup && (label = title_superscript)
      y += html ? " <sup>#{label}</sup>".html_safe : " (#{label})"
    end
    return html ? y.html_safe : y
  end

  def seqcode_url(protocol = true)
    "#{'https://' if protocol}seqco.de/s:#{id}"
  end

  def uri
    seqcode_url
  end

  def referenced_names
    @names ||= genomes.map(&:typified_names).flatten.compact.uniq
  end

  def names
    typified_names + referenced_names
  end

  def can_edit?(user)
    return false unless user
    return true if user.curator?
    return true unless typified_names.present?
    typified_names.all? { |name| name.can_edit?(user) }
  end

  def is_a_paratype?
    paratypified_names.any?
  end

  private

  def clean_numbers
    self.numbers_string =
      numbers_string.strip.gsub(/ +/, ' ').gsub(/ *= */, ' = ')
  end
end
