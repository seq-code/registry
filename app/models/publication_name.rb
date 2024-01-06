class PublicationName < ApplicationRecord
  belongs_to(:publication)
  belongs_to(:name)

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
