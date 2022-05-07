class AddAutoDataToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :gc_content_auto, :float, default: nil
    add_column :genomes, :completeness_auto, :float, default: nil
    add_column :genomes, :contamination_auto, :float, default: nil
    add_column :genomes, :most_complete_16s_auto, :float, default: nil
    add_column :genomes, :number_of_16s_auto, :integer, default: nil
    add_column :genomes, :most_complete_23s_auto, :float, default: nil
    add_column :genomes, :number_of_23s_auto, :integer, default: nil
    add_column :genomes, :number_of_trnas_auto, :integer, default: nil
  end
end
