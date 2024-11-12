class AddBiosampleAccession2ToSequencingExperiments < ActiveRecord::Migration[6.1]
  def change
    add_column :sequencing_experiments, :biosample_accession_2, :string, default: nil
  end
end
