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

  after_save(:harmonize_name_parent)

  def incertae_sedis_html
    return '' unless incertae_sedis?

    incertae_sedis.gsub(/(incertae sedis)/i, '<i>\\1</i>').html_safe
  end

  def downwards?
    Name.ranks.index(parent.inferred_rank) >=
      Name.ranks.index(name.inferred_rank)
  end

  private

  def harmonize_name_parent
    name.update(parent: parent) if preferred
  end
end
