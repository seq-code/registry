class Tag < ApplicationRecord
  has_rich_text(:description)

  # Self-referential parent/children
  belongs_to(:parent, class_name: 'Tag', optional: true)
  has_many(
    :children, class_name: 'Tag', foreign_key: 'parent_id',
    dependent: :nullify
  )

  # Names via join
  has_many(:name_tags, dependent: :destroy)
  has_many(:names, through: :name_tags)
  has_many(
    :accepted_names, -> { where(name_tags: { status_int: 1 }) },
    through: :name_tags, source: :name
  )

  validates(:name, presence: true, uniqueness: true)
  validates(:color, presence: true)
  validates(
    :slug, presence: true, uniqueness: true,
    format: {
      with: /\A[a-z0-9-]+\z/,
      message: 'only lowercase letters, digits, hyphens'
    }
  )
  validate(:parent_is_top_level)

  class << self
    def top_level
      where(parent_id: nil)
    end
  end

  # Convenience
  def umbrella?
    children.any?
  end

  def top_level?
    parent_id.nil?
  end

  private

  # The hierarchy is only two levels deep (umbrella → sub-tag), which also
  # rules out cycles
  def parent_is_top_level
    return if parent.nil?

    if parent == self
      errors.add(:parent, 'cannot be the tag itself')
    elsif !parent.top_level?
      errors.add(:parent, 'must be a top-level tag')
    elsif persisted? && children.any?
      errors.add(:parent, 'cannot be set on a tag that has sub-tags')
    end
  end
end
