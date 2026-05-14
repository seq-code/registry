class AddIndexesToNames < ActiveRecord::Migration[6.1]
  def change
    # Add indexes for frequently queried columns
    add_index :names, :rank
    add_index :names, :status
    add_index :names, :redirect_id
    add_index :names, :created_by_id
    add_index :names, :validated_by_id
    add_index :names, :priority_date
    add_index :names, :nomenclatural_type_type
    add_index :names, :nomenclatural_type_id

    # Composite indexes for common query patterns
    add_index :names, [:rank, :status]
    add_index :names, [:status, :priority_date]
  end
end
