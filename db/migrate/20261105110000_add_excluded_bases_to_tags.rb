class AddExcludedBasesToTags < ActiveRecord::Migration[6.1]
  def change
    # Terms (one per line) that never justify the tag on their own: proposals
    # of the tag whose basis is one of these terms are dropped
    add_column :tags, :excluded_bases, :text
  end
end
