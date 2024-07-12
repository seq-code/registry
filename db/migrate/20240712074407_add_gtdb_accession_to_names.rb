class AddGtdbAccessionToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :gtdb_accession, :string, default: nil
  end
end
