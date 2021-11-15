class AddNameToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :family, :string
    add_column :users, :given, :string
  end
end
