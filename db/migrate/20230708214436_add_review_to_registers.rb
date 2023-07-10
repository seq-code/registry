class AddReviewToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :nomenclature_review, :boolean, default: false
    add_column :registers, :genomics_review, :boolean, default: false
  end
end
