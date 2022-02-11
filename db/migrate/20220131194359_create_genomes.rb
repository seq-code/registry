class CreateGenomes < ActiveRecord::Migration[6.1]
  def change
    create_table :genomes do |t|
      t.string :database, null: false
      t.string :accession, null: false
      t.string :type, null: false
      t.float :gc_content, default: nil
      t.float :completeness, default: nil
      t.float :contamination, default: nil
      t.float :seq_depth, default: nil
      t.float :most_complete_16s, default: nil
      t.integer :number_of_16s, default: nil
      t.float :most_complete_23s, default: nil
      t.integer :number_of_23s, default: nil
      t.integer :number_of_trnas, default: nil
      t.integer :updated_by, default: nil
      t.boolean :auto_check, default: false

      t.timestamps
    end

    add_index :genomes, [:database, :accession], name: 'index_genomes_uniqueness', unique: true
    add_index :genomes, :type
    add_index :genomes, :updated_by
  end
end
