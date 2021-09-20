class AddTypeToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :type_material, :string, default: nil
    add_column :names, :type_accession, :text, default: nil
  end
end
