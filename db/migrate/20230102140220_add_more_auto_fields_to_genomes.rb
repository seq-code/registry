class AddMoreAutoFieldsToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :ambiguous_fraction, :float, default: nil
    add_column :genomes, :codon_table, :string, default: nil
  end
end
