class RenameApprovalToEndorsement < ActiveRecord::Migration[6.1]
  def change
    rename_column :names, :approved_by, :endorsed_by
    rename_column :names, :approved_at, :endorsed_at
  end
end
