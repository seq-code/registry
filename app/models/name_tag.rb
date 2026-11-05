class NameTag < ApplicationRecord
  belongs_to(:name)
  belongs_to(:tag)

  # Value of +pre_cascade_status_int+ for records created by the cascade
  CREATED_BY_CASCADE = -1

  # Username of whoever triggered the change, recorded on the tags accepted
  # through the cascade
  attr_accessor(:actor)

  # Don't create proposals of the implied tags when creating this one as
  # proposed (e.g., when they are created separately with their own notes)
  attr_accessor(:skip_implication_cascade)

  # Set on the records saved by the cascade itself, so it doesn't recurse
  attr_accessor(:cascading)

  validates(:name_id, uniqueness: { scope: :tag_id })
  validates(:status_int, presence: true, inclusion: { in: 0..2 })

  # Status changes cascade through the implied tags (see Tag.implied_closure)
  # on the same name: accepting a tag accepts all the tags it implies,
  # recording their previous status in +pre_cascade_status_int+, and undoing
  # the acceptance reverts them unless another accepted tag still implies
  # them. Proposing a tag also proposes the implied tags not yet on the name
  after_save(:cascade_acceptance, if: :became_accepted?, unless: :cascading)
  after_save(:cascade_undo, if: :stopped_being_accepted?, unless: :cascading)
  after_destroy(:cascade_undo, if: :accepted?, unless: :cascading)
  after_create(
    :cascade_proposal, if: :proposed?,
    unless: -> { cascading || skip_implication_cascade }
  )

  class << self
    def status
      %i[proposed accepted rejected]
    end

    def color
      %i[secondary success danger]
    end

    def status_opt
      status.each_with_index.to_a
    end
  end

  def status
    self.class.status[status_int]
  end

  def color
    self.class.color[status_int]
  end

  def accepted?
    status_int == 1
  end

  def proposed?
    status_int == 0
  end

  def rejected?
    status_int == 2
  end

  # Confidence reported by the tagging service (stored in +notes+ as
  # "confidence: high"), or +nil+ if none was recorded
  def confidence
    notes.to_s[/confidence: (\w+)/, 1]
  end

  # A status set directly (outside the cascade), even if unchanged, means
  # the record is no longer considered auto-accepted
  def status_int=(value)
    self.pre_cascade_status_int = nil unless cascading
    super
  end

  protected

  # Save as +status_int+ from within the cascade, appending +note+
  def cascade_change!(status_int, pre_cascade_status_int, note)
    self.cascading = true
    self.status_int = status_int
    self.pre_cascade_status_int = pre_cascade_status_int
    self.notes = [notes.presence, note].compact.join('; ')
    save!
  end

  private

  def became_accepted?
    saved_change_to_status_int? && accepted?
  end

  def stopped_being_accepted?
    saved_change_to_status_int? && status_int_before_last_save == 1 &&
      !accepted?
  end

  def implied_tag_ids
    Tag.implied_closure([tag_id]).keys - [tag_id]
  end

  def name_tags_for(tag_ids)
    NameTag.where(name_id: name_id, tag_id: tag_ids)
  end

  def cascade_create!(attributes)
    record = NameTag.new(name_id: name_id)
    record.cascading = true
    record.assign_attributes(attributes)
    record.save!
  end

  def cascade_acceptance
    slug = tag.slug
    ids = implied_tag_ids
    existing = name_tags_for(ids).index_by(&:tag_id)
    ids.each do |implied_id|
      record = existing[implied_id]
      if record.nil?
        cascade_create!(
          tag_id: implied_id, status_int: 1,
          proposed_by: actor.presence || proposed_by,
          notes: "accepted via #{slug}",
          pre_cascade_status_int: CREATED_BY_CASCADE
        )
      elsif !record.accepted?
        note = "accepted via #{slug}"
        note = "was rejected; #{note}" if record.rejected?
        record.cascade_change!(1, record.status_int, note)
      end
    end
  end

  # Revert the auto-accepted tags implied by this one, unless another tag
  # accepted directly on the name still implies them (auto-accepted tags
  # don't count: they are themselves implied by a directly accepted one)
  def cascade_undo
    records = name_tags_for(implied_tag_ids)
                .where.not(pre_cascade_status_int: nil).to_a
    return if records.empty?

    supporting_ids =
      NameTag.where(name_id: name_id, status_int: 1)
             .where(pre_cascade_status_int: nil)
             .where.not(id: id).pluck(:tag_id)
    supported = Tag.implied_closure(supporting_ids)
    note = "reverted: #{tag.slug} no longer accepted"
    records.each do |record|
      next if supported.key?(record.tag_id)

      if record.pre_cascade_status_int == CREATED_BY_CASCADE
        record.cascading = true
        record.destroy!
      else
        record.cascade_change!(record.pre_cascade_status_int, nil, note)
      end
    end
  end

  def cascade_proposal
    slug = tag.slug
    ids = implied_tag_ids
    present = name_tags_for(ids).pluck(:tag_id)
    (ids - present).each do |implied_id|
      cascade_create!(
        tag_id: implied_id, status_int: 0, proposed_by: proposed_by,
        notes: "implied by #{slug}"
      )
    end
  end
end
