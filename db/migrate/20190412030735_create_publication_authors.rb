class CreatePublicationAuthors < ActiveRecord::Migration[5.1]
  def change
    create_table :publication_authors do |t|
      t.integer :publication_id
      t.integer :author_id
      t.string :sequence

      t.timestamps
    end
    add_index :publication_authors, :publication_id
    add_index :publication_authors, :author_id
    add_index :publication_authors, [:publication_id, :author_id], unique: true
  end
end
