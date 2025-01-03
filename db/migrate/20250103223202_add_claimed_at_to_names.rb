class AddClaimedAtToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :claimed_at, :datetime
  end
end
