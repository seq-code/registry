class AddNomenclatureReviewerToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :nomenclature_reviewer, :integer, default: nil
  end
end
