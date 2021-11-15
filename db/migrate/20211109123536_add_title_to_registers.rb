class AddTitleToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :title, :string, default: nil
  end
end
