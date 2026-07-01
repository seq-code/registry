class AddCommunityAnswersToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :position, :string, default: nil
    add_column :users, :highest_degree, :string, default: nil
    add_column :users, :achievements, :text, default: nil
    add_column :users, :membership_societies, :string, default: nil
    add_column :users, :committee_interest, :boolean, default: nil
  end
end
