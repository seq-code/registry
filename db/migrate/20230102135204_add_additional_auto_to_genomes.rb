class AddAdditionalAutoToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :coding_density, :float, default: nil
    add_column :genomes, :n50, :int, default: nil
    add_column :genomes, :contigs, :int, default: nil
    add_column :genomes, :assembly_length, :int, default: nil
  end
end
