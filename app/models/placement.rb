class Placement < ApplicationRecord
  belongs_to(:name)
  belongs_to(
    :parent, optional: true, class_name: 'Name', foreign_key: 'parent_id'
  )
  belongs_to(:publication, optional: true)
  validates(:name, presence: true)
  validates(:parent, presence: true, unless: :incertae_sedis?)

  has_rich_text(:incertae_sedis_text)
  validates(:incertae_sedis_text, presence: true, if: :incertae_sedis?)
  validates(
    :incertae_sedis, absence: {
      if: :parent,
      message: 'cannot be declared if the parent taxon is set'
    }
  )

  validates(:preferred, uniqueness: { scope: :name_id, if: :preferred? })
end
