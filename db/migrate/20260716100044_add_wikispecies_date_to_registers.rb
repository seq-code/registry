class AddWikispeciesDateToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :wikispecies_at, :datetime, default: nil
  end
end
