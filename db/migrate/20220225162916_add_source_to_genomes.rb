class AddSourceToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :source_database, :string, null: true
    add_column :genomes, :source_accession, :string, null: true
  end
end
