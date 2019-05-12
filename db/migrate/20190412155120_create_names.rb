class CreateNames < ActiveRecord::Migration[5.1]
  def change
    create_table :names do |t|
      t.string :name

      t.timestamps
    end
    add_index :names, :name, unique: true
  end
end
