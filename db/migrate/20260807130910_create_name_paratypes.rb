class CreateNameParatypes < ActiveRecord::Migration[6.1]
  def change
    create_table :name_paratypes do |t|
      t.references :name, null: false, foreign_key: true
      t.references :nomenclatural_type, polymorphic: true, null: false

      t.timestamps
    end
  end
end
