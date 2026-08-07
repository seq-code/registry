class AddOfficerToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :officer, :boolean, default: false
  end
end
