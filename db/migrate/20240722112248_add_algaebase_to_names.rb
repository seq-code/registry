class AddAlgaebaseToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :algaebase_species, :string, default: nil
    add_column :names, :algaebase_taxonomy, :string, default: nil
  end
end
