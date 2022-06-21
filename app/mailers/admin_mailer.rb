class AdminMailer < ApplicationMailer
    default from: 'admin@example.com'
  
    def status_grant_email
      @user = params[:user]
      # logger = Rails.logger
      # logger.info "user email is: " + @user.email
      # logger.info "contributor status is: " + @user.contributor.to_s
      # logger.info "curator status is: " + @user.curator.to_s
      mail(to: @user.email, subject: 'Your Application Process Completed')
    end
  end
  