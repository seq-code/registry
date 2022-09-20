class UsersController < ApplicationController
  before_action(:authenticate_user!)
  before_action(
    :authenticate_admin!,
    only: %i[
      index show contributor_grant contributor_deny curator_grant curator_deny
    ]
  )
  before_action(
    :set_user,
    only: %i[show contributor_grant contributor_deny curator_grant curator_deny]
  )

  def index
    @users = User.all.order('created_at').paginate(page: params[:page], per_page: 30)
  end

  def show
    @names = Name.where(created_by: @user)
  end

  def dashboard
    redirect_to(root_url) unless user_signed_in?

    if current_user.admin?
      @contributor_applications = User.contributor_applications
      @curator_applications = User.curator_applications
    end
  end

  def contributor_request
    if current_user.academic_email?
      if current_user.update(contributor: true)
        flash[:notice] = 'Status automatically granted from academic email'
      else
        flash[:danger] = 'An unexpected error occurred, please try again later'
      end
      redirect_to(dashboard_path)
    end
  end

  def curator_request
  end

  def contributor_apply
    statement = params[:user][:contributor_statement] or nil
    statement = nil if statement.try(:empty?)
    if current_user.update(contributor_statement: statement)
      flash[:notice] =
        'Application received, we will evaluate it as soon as possible'
      redirect_to(dashboard_path)
      # TODO Notify all admins
    else
      flash[:alert] = 'Application failed'
      render 'contributor_request'
    end
  end

  def curator_apply
    statement = params[:user][:curator_statement] or nil
    statement = nil if statement.try(:empty?)
    if current_user.update(curator_statement: statement)
      flash[:notice] =
        'Application received, we will evaluate it as soon as possible'
      redirect_to dashboard_path
      # TODO Notify all admins
    else
      flash[:alert] = 'Application failed'
      render 'curator_request'
    end
  end

  def contributor_grant
    status_application_action(contributor: true)
  end

  def curator_grant
    status_application_action(curator: true, contributor: true)
  end

  def contributor_deny
    status_application_action(contributor_statement: nil)
  end

  def curator_deny
    status_application_action(curator_statement: nil)
  end

  private

    def status_application_action(params)
      if @user.update(params)
        flash[:notice] = 'Application successfully processed'
      else
        flash[:alert] = 'Error processing application, still pending'
      end
      redirect_to(dashboard_path)
    end

    def set_user
      @user = User.find_by(username: params[:username])
    end

end
