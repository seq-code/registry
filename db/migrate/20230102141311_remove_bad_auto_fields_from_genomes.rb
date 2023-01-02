class RemoveBadAutoFieldsFromGenomes < ActiveRecord::Migration[6.1]
  def change
    remove_column :genomes, :coding_density, :float
    remove_column :genomes, :n50, :int
    remove_column :genomes, :contigs, :int
    remove_column :genomes, :assembly_length, :int
    remove_column :genomes, :ambiguous_fraction, :float
    remove_column :genomes, :codon_table, :string
  end
end
