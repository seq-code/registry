class CreateRegisterCoauthors < ActiveRecord::Migration[6.1]
  def change
    create_table :register_coauthors do |t|
      t.references :register, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :order

      t.timestamps
    end
  end
end
