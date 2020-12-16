class PublicationName < ApplicationRecord
  belongs_to :publication
  belongs_to :name

  def proposes?
    name.proposed_by == publication
  end
end
