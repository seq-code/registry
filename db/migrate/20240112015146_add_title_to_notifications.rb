class AddTitleToNotifications < ActiveRecord::Migration[6.1]
  def change
    add_column :notifications, :title, :text
  end
end
