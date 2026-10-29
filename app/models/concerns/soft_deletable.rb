module SoftDeletable
  extend ActiveSupport::Concern

  included do
    default_scope { where(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def soft_deleted?
    deleted_at.present?
  end
end
