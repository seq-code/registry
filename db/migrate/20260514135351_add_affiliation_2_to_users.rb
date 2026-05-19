class AddAffiliation2ToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :affiliation_2, :string
    add_column :users, :affiliation_2_ror, :string
  end
end
