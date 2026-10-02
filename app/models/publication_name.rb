class PublicationName < ApplicationRecord
  include SoftDeletable

  belongs_to(:publication)
  belongs_to(:name)

  validates(
    :name,
    uniqueness: {
      scope: :publication_id, conditions: -> { where(deleted_at: nil) }
    },
    unless: :deleted?
  )

  def proposes?
    name.proposed_in? publication
  end

  def corrigendum?
    name.corrigendum_in? publication
  end

  def assigns?
    name.assigned_in? publication
  end
end
