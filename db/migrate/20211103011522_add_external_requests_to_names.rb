class AddExternalRequestsToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :irmng_json, :text, default: nil
    add_column :names, :irmng_at, :datetime, default: nil
    add_column :names, :col_json, :text, default: nil
    add_column :names, :col_at, :datetime, default: nil
  end
end
