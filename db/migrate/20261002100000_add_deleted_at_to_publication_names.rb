class AddDeletedAtToPublicationNames < ActiveRecord::Migration[6.1]
  def up
    add_column :publication_names, :deleted_at, :datetime
    remove_index :publication_names, column: %i[publication_id name_id], unique: true
    add_index :publication_names, %i[publication_id name_id],
              unique: true, where: 'deleted_at IS NULL'
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Soft deleted publication-name links cannot use the original unique index'
  end
end
