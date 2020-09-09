class AddJournalIndexToPublications < ActiveRecord::Migration[6.0]
  def change
    add_index :publications, :journal
  end
end
