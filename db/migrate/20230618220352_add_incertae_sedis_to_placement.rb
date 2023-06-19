class AddIncertaeSedisToPlacement < ActiveRecord::Migration[6.1]
  def change
    add_column :placements, :incertae_sedis, :string
  end
end
