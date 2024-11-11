class AddUniqueGenomeSequencingExperimentsIndex < ActiveRecord::Migration[6.1]
  def change
    add_index :genome_sequencing_experiments,
      [:genome_id, :sequencing_experiment_id],
      name: 'genome_sequencing_experiments_uniqueness',
      unique: true
  end
end
