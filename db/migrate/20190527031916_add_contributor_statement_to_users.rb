class AddContributorStatementToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :contributor_statement, :text
  end
end
