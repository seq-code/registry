class Current < ActiveSupport::CurrentAttributes
  # The user whose request is being handled. Versions record it as their author.
  attribute :user
end
