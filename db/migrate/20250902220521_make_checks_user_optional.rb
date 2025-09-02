class MakeChecksUserOptional < ActiveRecord::Migration[6.1]
  def change
    change_column_null(:checks, :user_id, true)
  end
end
