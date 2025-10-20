class AddUserToReports < ActiveRecord::Migration[6.1]
  def change
    add_column :reports, :user, :reference, default: nil
  end
end
