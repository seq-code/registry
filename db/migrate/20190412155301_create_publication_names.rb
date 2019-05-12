class CreatePublicationNames < ActiveRecord::Migration[5.1]
  def change
    create_table :publication_names do |t|
      t.integer :publication_id
      t.integer :name_id

      t.timestamps
    end
    add_index :publication_names, :publication_id
    add_index :publication_names, :name_id
    add_index :publication_names, [:publication_id, :name_id], unique: true
  end
end
