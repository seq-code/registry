class PublicationName < ApplicationRecord
  belongs_to(:publication)
  belongs_to(:name)

  after_create { record_history_event('publication_linked') }
  after_destroy { record_history_event('publication_unlinked') }

  def proposes?
    name.proposed_in? publication
  end

  def corrigendum?
    name.corrigendum_in? publication
  end

  def assigns?
    name.assigned_in? publication
  end

  private

  def record_history_event(kind)
    NameHistoryEvent.create!(
      name_id: name_id, kind: kind, data: { publication_id: publication_id }
    )
  end
end
