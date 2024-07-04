class CreateContacts < ActiveRecord::Migration[6.1]
  def change
    create_table :contacts do |t|
      t.references :publication, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :to
      t.string :cc
      t.string :subject
      t.references :author, null: false, foreign_key: true

      t.timestamps
    end
  end
end
