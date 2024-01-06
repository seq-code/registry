class FixPublicationIdsInNames < ActiveRecord::Migration[6.1]
  def change
    rename_column(:names, :proposed_by, :proposed_in_id)
    rename_column(:names, :corrigendum_by, :corrigendum_in_id)
    rename_column(:names, :assigned_by, :assigned_in_id)
  end
end
