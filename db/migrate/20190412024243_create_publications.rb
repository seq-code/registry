class CreatePublications < ActiveRecord::Migration[5.1]
  def change
    create_table :publications do |t|
      t.string :title
      t.string :journal
      t.string :journal_loc
      t.date :journal_date
      t.string :doi
      t.string :url
      t.string :type
      t.string :crossref_json

      t.timestamps
    end
    add_index :publications, :doi, unique: true
  end
end
