class CreateSequencingExperiments < ActiveRecord::Migration[6.1]
  def change
    create_table :sequencing_experiments do |t|
      t.string :sra_accession
      t.string :biosample_accession, default: nil
      t.string :sra_runs_string, default: nil
      t.text :metadata_xml, default: nil
      t.datetime :queued_external, default: nil

      t.timestamps
    end
    add_index :sequencing_experiments, :sra_accession, unique: true
  end
end
