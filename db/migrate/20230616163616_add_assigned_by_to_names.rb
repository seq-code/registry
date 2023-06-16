class AddAssignedByToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :assigned_by, :integer, default: nil
  end
end
