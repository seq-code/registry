class AddDepartmentsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :department, :string, default: nil
    add_column :users, :department_2, :string, default: nil
  end
end
