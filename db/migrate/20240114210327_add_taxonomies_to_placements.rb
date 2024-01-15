class AddTaxonomiesToPlacements < ActiveRecord::Migration[6.1]
  def change
    add_column :placements, :gtdb_taxonomy, :boolean
    add_column :placements, :ncbi_taxonomy, :boolean
  end
end
