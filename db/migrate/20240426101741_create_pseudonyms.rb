class CreatePseudonyms < ActiveRecord::Migration[6.1]
  def change
    create_table :pseudonyms do |t|
      t.string :pseudonym
      t.references :name, null: false, foreign_key: true
      t.string :kind, default: nil

      t.timestamps
    end
    add_index :pseudonyms, [:pseudonym, :name_id], unique: true
  end
end
