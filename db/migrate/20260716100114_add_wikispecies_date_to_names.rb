class AddWikispeciesDateToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :wikispecies_at, :datetime, default: nil
  end
end
