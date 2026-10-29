class EnforceOneActivePreferredPlacement < ActiveRecord::Migration[6.1]
  def change
    add_index :placements, :name_id, unique: true,
              where: 'preferred = TRUE AND deleted_at IS NULL',
              name: 'index_placements_on_active_preferred_name'
  end
end
