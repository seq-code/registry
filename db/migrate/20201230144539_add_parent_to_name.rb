class AddParentToName < ActiveRecord::Migration[6.0]
  def change
    add_column :names, :parent_id, :integer
  end
end
