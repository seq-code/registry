class Tag < ApplicationRecord
  # Confidence levels reported for tag proposals, from lowest to highest
  CONFIDENCE_LEVELS = %w[low medium high].freeze

  has_rich_text(:description)

  # Self-referential parent/children
  belongs_to(:parent, class_name: 'Tag', optional: true)
  has_many(
    :children, class_name: 'Tag', foreign_key: 'parent_id',
    dependent: :nullify
  )

  # Tags added automatically whenever this tag is proposed (besides the
  # parent), and the tags that add this one
  has_many(:tag_implications, dependent: :destroy)
  has_many(:implied_tags, through: :tag_implications)
  has_many(
    :inverse_tag_implications, class_name: 'TagImplication',
    foreign_key: :implied_tag_id, dependent: :destroy
  )
  has_many(:implying_tags, through: :inverse_tag_implications, source: :tag)

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

    # Expand tag +proposals+ (Array of Hash with String keys 'slug' and
    # 'confidence') with every tag they imply, directly or through a chain:
    # the parent of each proposed tag and its +implied_tags+. An implied tag
    # takes the highest confidence among the proposals implying it, which
    # can raise (but never lower) the confidence of a tag that was also
    # proposed directly. Implied entries record their provenance as
    # 'implied_by' => [slugs]. Every entry carries 'direct' => true if it was
    # proposed by the backend (even if also implied), false otherwise.
    # Unknown confidences are normalized to 'low'
    def expand(proposals)
      implied = implied_slugs_map
      expanded = {}
      proposals.each do |proposal|
        slug = proposal['slug']
        confidence = normalize_confidence(proposal['confidence'])
        entry = expanded[slug] ||=
          proposal.merge('confidence' => confidence, 'direct' => true)
        entry['confidence'] = max_confidence(entry['confidence'], confidence)
      end

      loop do
        changed = false
        expanded.values.each do |source|
          implied.fetch(source['slug'], []).each do |slug|
            entry = expanded[slug] ||= {
              'slug' => slug, 'confidence' => source['confidence'],
              'direct' => false
            }
            confidence =
              max_confidence(entry['confidence'], source['confidence'])
            implied_by = entry['implied_by'] || []
            next if confidence == entry['confidence'] &&
                    implied_by.include?(source['slug'])

            entry['confidence'] = confidence
            entry['implied_by'] = implied_by | [source['slug']]
            changed = true
          end
        end
        break unless changed
      end

      expanded.values
    end

    private

    # Slug => slugs of all implied tags (parent and implications), loaded in
    # one query
    def implied_slugs_map
      tags = includes(:parent, :implied_tags).to_a
      tags.to_h { |tag| [tag.slug, tag.all_implied_tags.map(&:slug)] }
    end

    def normalize_confidence(confidence)
      CONFIDENCE_LEVELS.include?(confidence) ? confidence : 'low'
    end

    def max_confidence(a, b)
      [a, b].max_by { |level| CONFIDENCE_LEVELS.index(level) }
    end
  end

  # Tags added automatically whenever this tag is proposed: the parent (if
  # any) and the explicitly implied tags
  def all_implied_tags
    ([parent] + implied_tags.to_a).compact.uniq
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
