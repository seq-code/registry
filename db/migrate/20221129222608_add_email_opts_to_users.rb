class AddEmailOptsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :opt_regular_email, :boolean, default: true
    add_column :users, :opt_notification, :boolean, default: true
  end
end
