class AddNameTagging < ActiveRecord::Migration[6.1]
  def up
    # Tag hierarchy and stable programmatic handle
    add_column :tags, :slug, :string
    execute <<~SQL
      UPDATE tags
      SET slug = TRIM(BOTH '-' FROM
                   REGEXP_REPLACE(LOWER(name), '[^a-z0-9]+', '-', 'g'))
    SQL
    change_column_null :tags, :slug, false
    add_index :tags, :slug, unique: true
    add_reference :tags, :parent, foreign_key: { to_table: :tags }

    # Tags applied to names
    create_table :name_tags do |t|
      t.references :name, null: false, foreign_key: true, index: false
      t.references :tag, null: false, foreign_key: true
      t.integer :status_int, null: false, default: 0
      t.string :proposed_by
      t.text :notes

      t.timestamps
    end
    add_index :name_tags, %i[name_id tag_id], unique: true
  end

  def down
    drop_table :name_tags
    remove_reference :tags, :parent, foreign_key: { to_table: :tags }
    remove_index :tags, :slug
    remove_column :tags, :slug
  end
end
