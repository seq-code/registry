class AddOptMessageEmailToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :opt_message_email, :boolean, default: true
  end
end
