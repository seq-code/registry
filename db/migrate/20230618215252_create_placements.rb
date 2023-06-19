class CreatePlacements < ActiveRecord::Migration[6.1]
  def change
    create_table :placements do |t|
      t.references :name, null: false, foreign_key: true
      t.integer :parent_id, default: nil
      t.references :publication, default: nil, null: true, foreign_key: true
      t.boolean :preferred, default: false

      t.timestamps
    end
  end
end
