class AddCuratorToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :curator, :boolean, default: false
    add_column :users, :curator_statement, :text
  end
end
