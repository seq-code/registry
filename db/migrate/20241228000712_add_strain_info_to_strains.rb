class AddStrainInfoToStrains < ActiveRecord::Migration[6.1]
  def change
    add_column :strains, :strain_info_json, :text, default: nil
    add_column :strains, :queued_external, :datetime, default: nil
  end
end
