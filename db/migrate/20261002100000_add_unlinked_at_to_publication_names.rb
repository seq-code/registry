class AddUnlinkedAtToPublicationNames < ActiveRecord::Migration[6.1]
  def change
    add_column :publication_names, :unlinked_at, :datetime
    remove_index :publication_names, column: %i[publication_id name_id], unique: true
    add_index :publication_names, %i[publication_id name_id],
              unique: true, where: 'unlinked_at IS NULL'
  end
end
