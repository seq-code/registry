class CreateReports < ActiveRecord::Migration[6.1]
  def change
    create_table :reports do |t|
      t.references :linkeable, polymorphic: true, null: false
      t.text :text
      t.text :html

      t.timestamps
    end
  end
end
