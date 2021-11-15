class AddAbstractToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :abstract, :text, default: nil
  end
end
