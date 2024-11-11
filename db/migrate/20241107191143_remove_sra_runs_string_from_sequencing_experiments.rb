class RemoveSraRunsStringFromSequencingExperiments < ActiveRecord::Migration[6.1]
  def change
    remove_column :sequencing_experiments, :sra_runs_string, :string
  end
end
