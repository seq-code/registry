class AddIdsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :orcid, :string, default: nil
    add_column :users, :affiliation_ror, :string, default: nil
  end
end
