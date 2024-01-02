module HasObservers

  # ============ --- EMAIL NOTIFICATIONS --- ============

  def notify_user(action, user)
    am = AdminMailer.with(
      user: user,
      object: self,
      action: action.to_s
    )

    case action.to_sym
    when :correspondence
      # For observers
      am.correspondence_email.deliver_later
    when :status
      # For observers
      am.observer_status_email.deliver_later
    else
      if is_a? Name
        # All other name status changes
        am.name_status_email.deliver_later
      elsif is_a? Register
        # All other register status changes
        am.register_status_email.deliver_later
      else
        raise 'Unknown class for observer notifications'
      end
    end
  end

  ##
  # Notify observers of a change via email
  # 
  # action: One of +:status+ or +:correspondence+
  # options:
  # - exclude_creator: Exclude creator from the list of observers notified
  # - exclude_users: Array of users to exclude from notified observers
  def notify_observers(action, exclude_creator: false, exclude_users: [])
    observers.each do |user|
      next if exclude_users.include?(user)
      next if exclude_creator && user == created_by

      notify_user(action, user)
    end
  end

  def notify_status_change(action, user)
    notify_user(action, created_by)
    notify_observers(
      :status, exclude_creator: true, exclude_users: [user]
    )
    true
  end

  # ============ --- HELPER FUNCTIONS FOR STATUS UPDATES --- ============

  def assert_status_with_alert(test, action)
    return true if test

    @status_alert = 'Status is incompatible with ' + action
    false
  end

  def update_status_with_alert(par)
    return true if update(par)

    @status_alert = 'An unexpected error occurred'
    false
  end
end
