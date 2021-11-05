class CreateNameCorrespondences < ActiveRecord::Migration[6.1]
  def change
    create_table :name_correspondences do |t|
      t.references :name, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :message

      t.timestamps
    end
  end
end
