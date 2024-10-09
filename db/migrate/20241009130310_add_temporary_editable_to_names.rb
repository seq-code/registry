class AddTemporaryEditableToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :temporary_editable_at, :datetime, default: nil
  end
end
