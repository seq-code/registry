class Strain < ApplicationRecord
  has_many(
    :typified_names, class_name: 'Name',
    as: :nomenclatural_type, dependent: :nullify
  )

  validates(:numbers_string, presence: true)

  before_save(:clean_numbers)

  def numbers
    numbers_string.split(' = ')
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

  private

  def clean_numbers
    self.numbers_string =
      numbers_string.strip.gsub(/ +/, ' ').gsub(/ *= */, ' = ')
  end
end
