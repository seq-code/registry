class ChangeGenomesTypeToKind < ActiveRecord::Migration[6.1]
  def change
    remove_column :genomes, :type, :string
    add_column :genomes, :kind, :string, null: true
  end
end
