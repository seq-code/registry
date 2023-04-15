class AddDoiToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :doi, :string, default: nil
  end
end
