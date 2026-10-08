module Unlinkable
  extend ActiveSupport::Concern

  included do
    scope :linked, -> { where(unlinked_at: nil) }
  end

  def unlink!
    update!(unlinked_at: Time.current)
  end

  def unlinked?
    unlinked_at.present?
  end
end
