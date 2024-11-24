class AddWikispeciesCheckedToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :wikispecies_checked_at, :datetime, default: nil
    add_column :names, :wikispecies_issues_text, :text, default: nil
  end
end
