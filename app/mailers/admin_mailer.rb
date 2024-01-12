class AdminMailer < ApplicationMailer
  layout 'admin_mailer'
  before_action do
    @user, @action, @object = params[:user], params[:action], params[:object]
  end
  default to: -> { @user.email }

  ##
  # Generic interface to automatically load the appropriate templated
  # email
  def templated_email
    case @action.to_sym
    when :correspondence
      # For observers
      correspondence_email
    when :status
      # For observers
      observer_status_email
    else
      if @object.is_a? Name
        # All other name status changes
        name_status_email
      elsif @object.is_a? Register
        # All other register status changes
        register_status_email
      else
        raise 'Unknown class for observer notifications'
      end
    end
  end

  ##
  # Email notifying of a user status change
  def user_status_email
    return unless @user.opt_regular_email?

    @params = params
    @action =
      if params[:params][:curator]
        %w[curator endorse]
      elsif params[:params][:contributor]
        %w[contributor endorse]
      elsif params[:params].has_key? :curator_statement
        %w[curator deny]
      elsif params[:params].has_key? :contributor_statement
        %w[contributor deny]
      else
        %w[unknown unknown]
      end

    mail(
      subject: 'New user status in SeqCode Registry',
      template_name: 'user_status_email'
    )
  end

  ##
  # Email notifying of a name status change
  def name_status_email
    return unless @user.opt_regular_email?

    @name = params[:name] || params[:object]

    mail(
      subject: 'New name status in SeqCode Registry',
      template_name: 'name_status_email'
    )
  end

  ##
  # Email notifying of a register list status change
  def register_status_email
    return unless @user.opt_regular_email?

    @register = params[:register] || params[:object]

    mail(
      subject: 'New register list status in SeqCode Registry',
      template_name: 'register_status_email'
    )
  end

  ##
  # Email notifying observers of a new correspondence
  def correspondence_email
    return unless @user.opt_message_email?

    @object = params[:object]

    mail(
      subject: 'New correspondence message in SeqCode Registry',
      template_name: 'correspondence_email'
    )
  end

  ##
  # Email notifying observers of a new status change
  def observer_status_email
    return unless @user.opt_regular_email?

    @object = params[:object]
    mail(
      subject: 'New status update in SeqCode Registry',
      template_name: 'observer_status_email'
    )
  end

  ##
  # Periodic reminder for contributors sent by +ReminderMail.register_reminder+
  def register_reminder_email
    return unless @user.opt_notification?

    @registers = params[:registers]

    mail(
      subject: 'SeqCode Monthly Reminder',
      template_name: 'register_reminder_email'
    )
  end

end
