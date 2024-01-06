class AddGenomicsReviewerToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :genomics_reviewer, :integer, default: nil
  end
end
