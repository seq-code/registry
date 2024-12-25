class GenericTypeMaterial < ApplicationRecord
  has_many(
    :typified_names, class_name: 'Name',
    as: :nomenclatural_type, dependent: :nullify
  )

  validates(:text, presence: true)

  def type_of_type
    'Other'
  end

  def display(_html = true)
    "#{type_of_type}: #{text}"
  end

  def old_type_definition
    ['other', text]
  end
end
