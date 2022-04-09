class AddGbifToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :gbif_json, :text, default: nil
    add_column :names, :gbif_at, :datetime, default: nil
  end
end
