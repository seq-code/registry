class RemoveCreatedAtFromChecks < ActiveRecord::Migration[6.1]
  def change
    remove_column :checks, :created_at, :datetime
  end
end
