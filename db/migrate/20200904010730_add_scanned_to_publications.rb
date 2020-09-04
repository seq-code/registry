class AddScannedToPublications < ActiveRecord::Migration[6.0]
  def change
    add_column :publications, :scanned, :boolean, default: false
  end
end
