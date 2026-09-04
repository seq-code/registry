class NameParatype < ApplicationRecord
  belongs_to(:name)
  belongs_to(:publication)
  belongs_to(:nomenclatural_type, polymorphic: true)

  validates(
    :nomenclatural_type_id,
    uniqueness: { scope: %i[name_id nomenclatural_type_type] }
  )
  # Per the SeqCode paratype amendment (DOI:10.1093/ismeco/ycaf238), only
  # isolated strains can serve as paratypes
  validates(:nomenclatural_type_type, inclusion: { in: %w[Strain] })

  after_create(:link_publication_to_name)

  private

  # A paratype's registering publication should also be recognized as one
  # of the name's own publications, same as propose/assign/emend/corrig
  # already ensure (see PublicationsController#create). Uses find_or_create
  # so this holds regardless of which code path creates the NameParatype,
  # and is a no-op if the publication is already linked.
  def link_publication_to_name
    PublicationName.find_or_create_by(publication: publication, name: name)
  end
end
