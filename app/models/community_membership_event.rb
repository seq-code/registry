##
# Append-only log of SeqCode Community membership events, kept for
# traceability (e.g., membership status at the time of a vote). It isn't used
# by the application itself
class CommunityMembershipEvent < ApplicationRecord
  EVENTS = %w[application renewal grant deny].freeze

  belongs_to(:user)

  validates(:event, inclusion: { in: EVENTS })
end
