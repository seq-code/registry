class CreateAuthors < ActiveRecord::Migration[5.1]
  def change
    create_table :authors do |t|
      t.string :given
      t.string :family

      t.timestamps
    end
    add_index :authors, [:given, :family], unique: true
  end
end
