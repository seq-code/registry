class AddLargestContigAutoToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :largest_contig_auto, :integer, default: nil
  end
end
