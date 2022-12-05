class AddSubmittedAtToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :submitted_at, :datetime, default: nil
  end
end
