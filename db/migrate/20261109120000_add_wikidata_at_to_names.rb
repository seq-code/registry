class AddWikidataAtToNames < ActiveRecord::Migration[6.1]
  def change
    # Last time the name was looked up in Wikidata without finding an item
    add_column :names, :wikidata_at, :datetime, default: nil
  end
end
