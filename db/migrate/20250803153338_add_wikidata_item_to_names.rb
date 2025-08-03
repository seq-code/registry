class AddWikidataItemToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :wikidata_item, :string, default: nil
  end
end
