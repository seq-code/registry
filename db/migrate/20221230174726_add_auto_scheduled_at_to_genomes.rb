class AddAutoScheduledAtToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :auto_scheduled_at, :datetime, default: nil
  end
end
