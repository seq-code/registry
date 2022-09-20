class CreateRegisterCorrespondences < ActiveRecord::Migration[6.1]
  def change
    create_table :register_correspondences do |t|
      t.references :register, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
