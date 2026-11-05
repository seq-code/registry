class TagImplication < ApplicationRecord
  belongs_to(:tag)
  belongs_to(:implied_tag, class_name: 'Tag')

  validates(:implied_tag_id, uniqueness: { scope: :tag_id })
  validate(:not_self_implied)

  private

  def not_self_implied
    return if implied_tag_id.nil? || implied_tag_id != tag_id

    errors.add(:implied_tag, 'cannot be the tag itself')
  end
end
