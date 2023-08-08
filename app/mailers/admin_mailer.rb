class AdminMailer < ApplicationMailer
  layout 'admin_mailer'
  before_action { @user, @action = params[:user], params[:action] }
  default to: -> { @user.email }

  ##
  # Email notifying of a user status change
  def user_status_email
    return unless @user.opt_regular_email

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
    mail(subject: 'New user status in SeqCode Registry')
  end

  ##
  # Email notifying of a name status change
  def name_status_email
    return unless @user.opt_regular_email

    @name = params[:name]
    mail(subject: 'New name status in SeqCode Registry')
  end

  ##
  # Email notifying of a register list status change
  def register_status_email
    return unless @user.opt_regular_email

    @register = params[:register]
    mail(subject: 'New register list status in SeqCode Registry')
  end

  ##
  # Periodic reminder for contributors sent by +ReminderMail.register_reminder+
  def register_reminder_email
    return unless @user.opt_notification?

    @registers = params[:registers]
    mail(subject: 'SeqCode Monthly Reminder')
  end

end
