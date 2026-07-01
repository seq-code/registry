class AddCommunityMemberToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :community_member, :bool, default: false
  end
end
