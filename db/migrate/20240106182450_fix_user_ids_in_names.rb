class FixUserIdsInNames < ActiveRecord::Migration[6.1]
  def change
    rename_column(:names, :created_by, :created_by_id)
    rename_column(:names, :submitted_by, :submitted_by_id)
    rename_column(:names, :endorsed_by, :endorsed_by_id)
    rename_column(:names, :validated_by, :validated_by_id)
    rename_column(:names, :nomenclature_review_by, :nomenclature_review_by_id)
    rename_column(:names, :genomics_review_by, :genomics_review_by_id)
  end
end
