class FixUserIdsInRegisters < ActiveRecord::Migration[6.1]
  def change
    rename_column(:registers, :validated_by, :validated_by_id)
    rename_column(:registers, :published_by, :published_by_id)
  end
end
