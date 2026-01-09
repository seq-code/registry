class Strain < ApplicationRecord
  has_many(
    :typified_names, -> { where(redirect_id: nil) },
    class_name: 'Name', as: :nomenclatural_type, dependent: :nullify
  )
  has_many(:genomes, dependent: :nullify)

  validates(:numbers_string, presence: true)

  before_save(:clean_numbers)

  include HasExternalResources
  include Strain::ExternalResources

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

  def title(prefix = nil)
    prefix ||= 'Strain '
    '%ssc|%07i' % [prefix, id]
  end

  def text
    title('')
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

  private

  def clean_numbers
    self.numbers_string =
      numbers_string.strip.gsub(/ +/, ' ').gsub(/ *= */, ' = ')
  end
end
