class FixReviewerIdsInName < ActiveRecord::Migration[6.1]
  def change
    rename_column(:names, :nomenclature_reviewer, :nomenclature_review_by)
    rename_column(:names, :genomics_reviewer, :genomics_review_by)
  end
end
