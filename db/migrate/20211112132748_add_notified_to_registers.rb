class AddNotifiedToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :notified, :boolean, default: false
    add_column :registers, :notified_at, :datetime, default: nil
  end
end
