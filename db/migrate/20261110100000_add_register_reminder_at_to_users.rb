class AddRegisterReminderAtToUsers < ActiveRecord::Migration[6.1]
  def change
    # Last time the user was sent a register reminder, so reminders can be
    # spread over several days without sending anyone a duplicate
    add_column :users, :register_reminder_at, :datetime, default: nil
  end
end
