class AddQueuedExternalToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :queued_external, :datetime, default: nil
  end
end
