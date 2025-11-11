class ChangeDefaultToCurationStatus < ActiveRecord::Migration[6.1]
  def change
    change_column_default :curations, :status_int, 0
  end
end
