class AddUnlinkedAtToPlacements < ActiveRecord::Migration[6.1]
  def change
    add_column :placements, :unlinked_at, :datetime
  end
end
