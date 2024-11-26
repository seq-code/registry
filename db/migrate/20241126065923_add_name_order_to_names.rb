class AddNameOrderToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :name_order, :text, default: nil
    add_index :names, :name_order
  end
end
