class CreateTagImplications < ActiveRecord::Migration[6.1]
  def change
    # Tags that are added automatically whenever another tag is proposed
    # (e.g., mythonym → mythological), beyond the tag's own umbrella
    create_table :tag_implications do |t|
      t.references(:tag, null: false, foreign_key: true, index: false)
      t.references(
        :implied_tag, null: false, foreign_key: { to_table: :tags }
      )
      t.timestamps
    end
    add_index(:tag_implications, %i[tag_id implied_tag_id], unique: true)
  end
end
