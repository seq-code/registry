class AddValidatedAtToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :validated_at, :datetime
  end
end
