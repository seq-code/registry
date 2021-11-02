class AddNotesToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :notes, :text
  end
end
