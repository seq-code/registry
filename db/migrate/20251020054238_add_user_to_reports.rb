class AddUserToReports < ActiveRecord::Migration[6.1]
  def change
    add_reference :reports, :user, default: nil, foreign_key: true
  end
end
