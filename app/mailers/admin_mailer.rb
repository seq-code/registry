class AdminMailer < ApplicationMailer
  layout 'admin_mailer'
  before_action { @user, @action = params[:user], params[:action] }
  default to: -> { @user.email }

  ##
  # Email notifying of a user status change
  def user_status_email
    @params = params
    @action =
      if params[:params][:curator]
        %w[curator approve]
      elsif params[:params][:contributor]
        %w[contributor approve]
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
    @name = params[:name]
    mail(subject: 'New name status in SeqCode Registry')
  end

  ##
  # Email notifying of a register list status change
  def register_status_email
    @register = params[:register]
    mail(subject: 'New register list status in SeqCode Registry')
  end

  ##
  # Periodic reminder for contributors
  def register_reminder_email
    @registers = params[:registers]
    mail(subject: 'SeqCode Weekly Reminder')
  end

end
