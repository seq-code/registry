class AddWikispeciesToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :wikispecies_entry, :string
  end
end
