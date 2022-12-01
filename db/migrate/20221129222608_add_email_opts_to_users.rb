class AddEmailOptsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :opt_regular_email, :boolean, default: false
    add_column :users, :opt_notification, :boolean, default: false
  end
end
