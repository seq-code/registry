class AddAutomaticToNameCorrespondence < ActiveRecord::Migration[6.1]
  def change
    add_column :name_correspondences, :automatic, :boolean, default: false
  end
end
