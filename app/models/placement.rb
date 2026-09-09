class Placement < ApplicationRecord
  belongs_to(:name)
  belongs_to(
    :parent, optional: true, class_name: 'Name', foreign_key: 'parent_id'
  )
  belongs_to(:publication, optional: true)
  validates(:name, presence: true)
  validates(:parent, presence: true)

  has_rich_text(:incertae_sedis_text)
  validates(:incertae_sedis_text, presence: true, if: :incertae_sedis?)
  validates(
    :incertae_sedis, inclusion: { in: [true, false] }
  )
  validates(:preferred, uniqueness: { scope: :name_id, if: :preferred? })

  after_save(:harmonize_name_parent)

  def incertae_sedis_html
    return '' unless incertae_sedis?

    ActionController::Base.helpers.safe_join(
      ['<i>incertae sedis</i>'.html_safe, (" (#{parent.name})" if parent)].compact
    )
  end

  def allowed_parent_ranks(incertae_sedis: incertae_sedis?)
    rank_index = name&.rank_index
    return [] unless rank_index && rank_index.positive?

    if incertae_sedis
      Name.ranks.take(rank_index - 1)
    else
      [Name.ranks[rank_index - 1]]
    end
  end

  def downwards?
    return false unless parent.present? # e.g., incertae sedis

    Name.ranks.index(parent.inferred_rank) >=
      Name.ranks.index(name.inferred_rank)
  end

  private

  def harmonize_name_parent
    name.update(parent: incertae_sedis? ? nil : parent) if preferred
  end
end
