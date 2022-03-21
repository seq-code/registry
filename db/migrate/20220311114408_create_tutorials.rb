class CreateTutorials < ActiveRecord::Migration[6.1]
  def change
    create_table :tutorials do |t|
      t.string :pipeline
      t.references :user, null: false, foreign_key: true
      t.boolean :ongoing
      t.integer :step

      t.timestamps
    end
  end
end
