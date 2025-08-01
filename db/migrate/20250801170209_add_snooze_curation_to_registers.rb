class AddSnoozeCurationToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :snooze_curation, :datetime, default: nil
  end
end
