class AddAutomaticToRegisterCorrespondence < ActiveRecord::Migration[6.1]
  def change
    add_column :register_correspondences, :automatic, :boolean, default: false
  end
end
