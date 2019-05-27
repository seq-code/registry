class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin!, only: [:index, :show, :contributor_grant, :contributor_deny]
  before_action :set_user, only: [:show, :contributor_grant, :contributor_deny]

  def index
    @users = User.all
  end

  def show
  end

  def dashboard
    redirect_to root_url unless user_signed_in?
    @contributor_applications = User.contributor_applications
  end

  def contributor_request
  end

  def contributor_apply
    statement = params[:user][:contributor_statement] or nil
    statement = nil if statement.try(:empty?)
    if current_user.update(contributor_statement: statement)
      flash[:notice] = 'Application received, we will evaluate it as soon as possible'
      redirect_to dashboard_path
    else
      flash[:alert] = 'Application failed'
      render 'contributor_request'
    end
  end

  def contributor_grant
    contributor_application_action(contributor: true)
  end

  def contributor_deny
    contributor_application_action(contributor_statement: nil)
  end

  private

    def contributor_application_action(params)
      if @user.update(params)
        flash[:notice] = 'Application successfully processed'
      else
        flash[:alert] = 'Error processing application, still pending'
      end
      redirect_to dashboard_path
    end

    def set_user
      @user = User.find_by(username: params[:username])
    end

end
