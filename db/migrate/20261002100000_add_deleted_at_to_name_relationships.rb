class AddDeletedAtToNameRelationships < ActiveRecord::Migration[6.1]
  def change
    add_column :publication_names, :deleted_at, :datetime
    remove_index :publication_names, column: %i[publication_id name_id], unique: true
    add_index :publication_names, %i[publication_id name_id],
              unique: true, where: 'deleted_at IS NULL'

    add_column :placements, :deleted_at, :datetime
  end
end
