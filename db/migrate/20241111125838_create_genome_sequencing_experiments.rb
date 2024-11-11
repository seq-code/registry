class CreateGenomeSequencingExperiments < ActiveRecord::Migration[6.1]
  def change
    create_table :genome_sequencing_experiments do |t|
      t.references :genome, null: false, foreign_key: true
      t.references :sequencing_experiment, null: false, foreign_key: true

      t.timestamps
    end
  end
end
