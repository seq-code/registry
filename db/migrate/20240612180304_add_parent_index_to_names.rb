class AddParentIndexToNames < ActiveRecord::Migration[6.1]
  def change
    add_index :names, :parent_id
  end
end
