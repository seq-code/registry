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
end
