class AddAutoFieldsToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :coding_density_auto, :float, default: nil
    add_column :genomes, :n50_auto, :int, default: nil
    add_column :genomes, :contigs_auto, :int, default: nil
    add_column :genomes, :assembly_length_auto, :int, default: nil
    add_column :genomes, :ambiguous_fraction_auto, :float, default: nil
    add_column :genomes, :codon_table_auto, :string, default: nil
  end
end
