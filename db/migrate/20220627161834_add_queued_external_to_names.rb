class AddQueuedExternalToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :queued_external, :datetime, default: nil
  end
end
