class AddInternalNotesToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :internal_notes, :text
  end
end
