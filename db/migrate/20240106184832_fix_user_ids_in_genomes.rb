class FixUserIdsInGenomes < ActiveRecord::Migration[6.1]
  def change
    rename_column(:genomes, :updated_by, :updated_by_id)
  end
end
