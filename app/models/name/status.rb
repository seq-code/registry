module Name::Status
  # ============ --- GENERIC STATUS --- ============

  attr_accessor :status_alert

  def status_name
    status_hash[:name]
  end

  def status_help
    status_hash[:help].gsub(/\n/, ' ')
  end

  def status_symbol
    status_hash[:symbol]
  end

  def validated?
    status_hash[:valid]
  end

  def public?
    status_hash[:public]
  end

  def after_claim?
    status >= 5
  end

  def after_register?
    register.present? || after_submission?
  end

  def after_submission?
    status >= 10
  end

  def after_endorsement?
    status >= 12
  end

  def after_notification?
    validated? || register.try(:notified?)
  end

  def after_endorsement_or_notification?
    after_endorsement? || after_notification?
  end

  def after_validation?
    validated?
  end

  def after_register_publication?
    register.try(:published?)
  end

  def in_curation?
    after_submission? && !validated?
  end

  # ============ --- CHANGE STATUS --- ============

  ##
  # Return the name back to the authors
  # 
  # user: The user returning the name (the current user)
  def return(user)
    assert_status_with_alert(after_submission?, 'return') or return false
    update_status_with_alert(status: 5) or return false
    notify_status_change(:return, user)
  end

  ##
  # Validate the name
  #
  # user: The user validating the name (the current user)
  # code: Once of 'icnp' or 'icn'. Validation under SeqCode can only
  #       be done through a register list
  def validate(user, code)
    if !%w[icnp icn].include?(code)
      @status_alert = 'Invalid procedure for nomenclatural code ' + code
      return false
    end

    assert_status_with_alert(!validated?, 'validation') or return false
    update_status_with_alert(
      status: code == 'icnp' ? 20 : 25,
      validated_by: user, validated_at: Time.now
    ) or return false
    notify_status_change(:validate, user)
  end

  ##
  # Endorse the name for future publication
  # 
  # user: The user endorsing the name (the current user)
  def endorse(user)
    assert_status_with_alert(!after_endorsement?, 'endorsement') or return false
    update_status_with_alert(
      status: 12, endorsed_by: user, endorsed_at: Time.now
    ) or return false
    notify_status_change(:endorse, user)
  end

  ##
  # Claim the name
  #
  # user: The user claiming the name (usually the current user)
  # notify: Should user(s) be notified of status change?
  def claim(user, notify = true)
    if !can_claim?(user)
      @status_alert = 'User cannot claim name'
      return false
    end

    par = { created_by: user, created_at: Time.now }
    par[:status] = 5 if auto?
    update_status_with_alert(par) or return false

    add_observer(user)
    notify_status_change(:claim, user) if notify
    true
  end

  ##
  # Unclaim the name
  #
  # user: The user marking the name as unclaimed (the current user)
  def unclaim(user)
    if !can_unclaim?(user)
      @status_alert = 'User cannot unclaim name'
      return false
    end

    update_status_with_alert(status: 0) or return false
    notify_status_change(:unclaim, user)
    true
  end

  ##
  # Demote the name
  #
  # user: The user demoting the name
  def demote(user)
    if !user.admin?
      @status_alert = 'User cannot demote name'
      return false
    end

    update_status_with_alert(status: 0) or return false
    # This change does not trigger notifications, as it is intended only for
    # internal curation
    true
  end
end
