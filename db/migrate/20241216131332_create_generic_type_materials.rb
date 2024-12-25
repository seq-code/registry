class CreateGenericTypeMaterials < ActiveRecord::Migration[6.1]
  def change
    create_table :generic_type_materials do |t|
      t.string :text, null: false

      t.timestamps
    end
  end
end
