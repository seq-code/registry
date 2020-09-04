class ChangeDefaultBooleans < ActiveRecord::Migration[6.0]
  def change
    change_column_default(:users, :admin, false)
    change_column_default(:users, :contributor, false)
  end
end
