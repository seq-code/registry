class CreateRegisters < ActiveRecord::Migration[6.1]
  def change
    create_table :registers do |t|
      t.string :accession, default: nil
      t.references :user, null: false, foreign_key: true
      t.integer :validated_by, default: nil
      t.boolean :submitted, default: false
      t.boolean :validated, default: false
      t.references :publication, null: true, foreign_key: true

      t.timestamps
    end
    add_index :registers, :submitted
    add_index :registers, :validated
    add_index :registers, :accession, unique: true
  end
end
