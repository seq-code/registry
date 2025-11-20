module HasObservers

  # ============ --- EMAIL NOTIFICATIONS --- ============

  def notify_user(action, user, title)
    par = {
      user: user, notifiable: self, linkeable: self,
      action: action, title: title
    }
    $stderr.puts par
    Notification.create(par)
  end

  ##
  # Notify observers of a change via email
  # 
  # - action: One of +:status+ or +:correspondence+
  # - options:
  #   - title: Use this title instead of a generic auto-generated one
  #   - exclude_users: Array of users to exclude from notified observers
  def notify_observers(action, title: nil, exclude_users: [])
    # Generate notification title
    title ||= '%s in %s' % [
      action == :status ? 'Status change' : 'New correspondence',
      display(false)
    ]

    # Notify each user
    observers.each do |user|
      notify_user(action, user, title) unless exclude_users.include?(user)
    end
  end

  ##
  # Notify owner and observers of a status change via email
  #
  # - action: Action causing the status change, such as +:return+,
  #     +:validate+, +:endorse+, +:submit+, etc
  # - user: The user triggering the +action+
  def notify_status_change(action, user)
    title = 'Status change in %s: %s' % [display(false), action]
    notify_user(action, created_by, title) if created_by
    notify_observers(
      :status, title: title, exclude_users: [user, created_by]
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

  ## ============ --- HELPER FUNCTIONS FOR CURATION --- ============

  def observing_curators
    @observing_curators ||=
      observers.where(curator: true).where.not(id: created_by.try(:id))
  end

  def observing_curators?
    observing_curators.any?
  end
end
