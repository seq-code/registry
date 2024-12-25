class CreateStrains < ActiveRecord::Migration[6.1]
  def change
    create_table :strains do |t|
      t.string :numbers_string, null: false

      t.timestamps
    end
  end
end
