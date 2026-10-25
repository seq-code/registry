class CreateCommunityMembershipEvents < ActiveRecord::Migration[6.1]
  def change
    # Append-only log of SeqCode Community membership events, kept for
    # traceability (e.g., membership status at the time of a vote)
    create_table :community_membership_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event, null: false
      t.datetime :created_at, null: false
    end
  end
end
