class UsersController < ApplicationController
  before_action(:authenticate_user!)
  before_action(
    :authenticate_admin_curator_or_editor!,
    only: %i[show update]
  )
  before_action(
    :authenticate_admin!,
    only: %i[index contributor_grant contributor_deny curator_grant curator_deny]
  )
  before_action(
    :authenticate_officer!,
    only: %i[
      community_member_grant community_member_deny community_members_active
    ]
  )
  before_action(
    :set_user,
    only: %i[
      show update contributor_grant contributor_deny curator_grant curator_deny
      community_member_grant community_member_deny
    ]
  )

  def index
    @users = User.all.order('created_at')
                 .paginate(page: params[:page], per_page: 30)
  end

  def show
    @names = Name.where(created_by: @user)
    @registers = Register.where(user: @user)
    @tutorials = Tutorial.where(user: @user)
  end

  # POST /sysusers/:username
  def update
    par = params.require(:user).permit(
      :given, :family, :orcid, :affiliation, :affiliation_ror, :affiliation_2, :affiliation_2_ror
    )
    if @user.update(par)
      flash[:notice] = 'User updated successfully'
    else
      flash[:alert] = 'An error occurred while updating the user data'
    end
    redirect_back(fallback_location: @user)
  end

  def dashboard
    redirect_to(root_url) unless user_signed_in?
    @pending = { main: current_user.unseen_notifications.count }
    @crumbs = ['User dashboard']

    if current_user.admin?
      @contributor_applications = User.contributor_applications
      @curator_applications = User.curator_applications
      @pending[:admin] =
        @contributor_applications.count + @curator_applications.count
    end

    if current_user.curator?
      @pending_registers =
        params[:snoozed] ?
          Register.snoozed_for_curation : Register.pending_for_curation
      @pending[:curator] = @pending_registers.count
    end

    if current_user.editor?
      @unpublished_registers =
        Register.where(validated: true, published: [false, nil])
      @pending[:editor] = @unpublished_registers.count
    end

    if current_user.officer?
      @community_member_applications = User.community_member_applications
      @active_community_members = User.community_members_active
      @pending[:officer] = @community_member_applications.count
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

  def community_member_update
    par = params.require(:user).permit(
      :given, :family, :affiliation, :affiliation_2, :department,
      :department_2, :position, :highest_degree, :achievements,
      :membership_societies, :committee_interest
    )
    if par[:position] == 'Other'
      par[:position] =
        params.dig(:user, :position_other).presence || par[:position]
    end
    if par[:highest_degree] == 'Other'
      par[:highest_degree] =
        params.dig(:user, :highest_degree_other).presence ||
        par[:highest_degree]
    end
    if current_user.update(par)
      flash[:notice] = 'Profile updated successfully'
    else
      flash[:alert] = 'An error occurred while updating your data'
    end
    redirect_to(dashboard_path(tab: :community_member))
  end

  def community_member_apply
    event =
      current_user.community_member_started_on? ? 'renewal' : 'application'
    if current_user.can_apply_for_community_membership? &&
       current_user.community_member_profile_complete? &&
       current_user.update_community_membership(
         { community_member_applied_at: Time.current }, event
       )
      flash[:notice] =
        'Application received, we will evaluate it as soon as possible'
      # TODO Notify all officers
    else
      flash[:alert] = 'Application failed'
    end
    redirect_to(dashboard_path(tab: :community_member))
  end

  def community_member_grant
    status_application_action({
      community_member: true,
      community_member_applied_at: nil,
      community_member_started_on:
        @user.community_member_started_on || Date.current,
      community_member_expires_on: User.community_membership_cohort_end
    }, membership_event: 'grant')
  end

  def community_member_deny
    status_application_action(
      { community_member_applied_at: nil }, membership_event: 'deny'
    )
  end

  # GET /community_members/active
  # GET /community_members/active.csv
  def community_members_active
    members = User.community_members_active.order(:family, :given)
    respond_to do |format|
      format.html do
        @crumbs = [
          ['Officer dashboard', dashboard_path(tab: :officer)],
          'Active community members'
        ]
        @members = members.paginate(page: params[:page], per_page: 30)
      end
      format.csv do
        send_data(
          community_members_csv(members), type: 'text/csv',
          filename: "seqcode-community-members-#{Date.current}.csv"
        )
      end
    end
  end

  private

    def community_members_csv(members)
      CSV.generate do |rows|
        rows << ['Full name', 'Email', 'Affiliation', 'Department', 'Position']
        members.each do |u|
          rows << [
            u.full_name, u.email, u.affiliation, u.department, u.position
          ].map { |value| csv_safe(value) }
        end
      end
    end

    # Prevent spreadsheet applications from interpreting user-provided
    # +value+ as a formula
    def csv_safe(value)
      value.to_s.start_with?('=', '+', '-', '@') ? "'#{value}" : value
    end

    # Update the +@user+ status with +params+, and record +membership_event+
    # if it's a SeqCode Community membership change
    def status_application_action(params, membership_event: nil)
      updated =
        if membership_event
          @user.update_community_membership(params, membership_event)
        else
          @user.update(params)
        end
      if updated
        flash[:notice] = 'Application successfully processed'

        # Notify user
        AdminMailer.with(user: @user, params: params)
                   .user_status_email.deliver_later
      else
        flash[:alert] = 'Error processing application, still pending'
      end
      redirect_to(dashboard_path)
    end

    def set_user
      @user = User.find_by(username: params[:username])
    end

end
