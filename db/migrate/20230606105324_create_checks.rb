class CreateChecks < ActiveRecord::Migration[6.1]
  def change
    create_table :checks do |t|
      t.references :name, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :kind, null: false
      t.boolean :pass

      t.timestamps
    end
    add_index :checks, [:name_id, :kind], unique: true
  end
end
