class CreateObserveNames < ActiveRecord::Migration[6.1]
  def change
    create_table :observe_names do |t|
      t.references :user, null: false, foreign_key: true
      t.references :name, null: false, foreign_key: true

      t.timestamps
    end
  end
end
