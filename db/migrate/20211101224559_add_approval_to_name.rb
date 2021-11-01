class AddApprovalToName < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :approved_by, :integer
    add_column :names, :approved_at, :datetime
  end
end
