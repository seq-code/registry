class AddCommunityMembershipTrackingToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :community_member_applied_at, :datetime, default: nil
    add_column :users, :community_member_started_on, :date, default: nil
    add_column :users, :community_member_expires_on, :date, default: nil
  end
end
