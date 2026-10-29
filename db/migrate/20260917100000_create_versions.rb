class CreateVersions < ActiveRecord::Migration[6.1]
  def change
    create_table :versions do |t|
      t.references :record, polymorphic: true, null: false
      t.references :user, foreign_key: true
      t.string :operation, null: false
      t.jsonb :changeset, null: false
      t.datetime :created_at, null: false
    end
  end
end
