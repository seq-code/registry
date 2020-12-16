class AddProposedByToNames < ActiveRecord::Migration[6.0]
  def change
    add_column :names, :proposed_by, :integer, default: nil
  end
end
