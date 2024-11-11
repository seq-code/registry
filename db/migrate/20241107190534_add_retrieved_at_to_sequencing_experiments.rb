class AddRetrievedAtToSequencingExperiments < ActiveRecord::Migration[6.1]
  def change
    add_column :sequencing_experiments, :retrieved_at, :datetime, default: nil
  end
end
