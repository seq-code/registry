class CreateCurations < ActiveRecord::Migration[6.1]
  def change
    create_table :curations do |t|
      t.references :name, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :kind_int, null: false
      t.integer :status_int, default: 1
      t.text :notes

      t.timestamps
    end
  end
end
