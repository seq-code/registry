# frozen_string_literal: true

# Controller for user-related actions on names.
class Names::UserActionsController < Names::BaseController
  # GET /names/1/transfer_user
  def transfer_user
  end

  # POST /names/1/transfer_user
  def transfer_user_commit
    old_user = @name.user
    username = params.require(:name)[:user]
    user = User.find_by_email_or_username(username)

    if !user.present?
      flash[:alert] = 'The user could not be found'
      render :transfer_user
    elsif @name.transfer(current_user, user)
      add_automatic_correspondence(
        'SeqCode Register transferred from %s to %s' % [
          old_user&.username, user&.username
        ]
      )
      flash[:notice] =
        'Name successfully transferred to the new user'
      redirect_to(@name)
    else
      flash[:alert] =
        'The list has not been transferred due to a failed check: ' +
        @name.status_alert
      render :transfer_user
    end
  end

  # GET /names/1/observe
  def observe
    @name.add_observer(current_user)
    if params[:from] && RedirectSafely.safe?(params[:from])
      redirect_to(params[:from])
    else
      redirect_back(fallback_location: @name)
    end
  end

  # GET /names/1/unobserve
  def unobserve
    @name.observers.delete(current_user)
    if params[:from] && RedirectSafely.safe?(params[:from])
      redirect_to(params[:from])
    else
      redirect_back(fallback_location: @name)
    end
  end

  # POST /names/1/new_correspondence
  def new_correspondence
    @name_correspondence = NameCorrespondence.new(
      params.require(:name_correspondence).permit(:message, :notify)
    )
    unless @name_correspondence.message.empty?
      @name_correspondence.user = current_user
      @name_correspondence.name = @name
      if @name_correspondence.save
        @name.add_observer(current_user)
        @name.register.try(:unsnooze_curation!)
        flash[:notice] = 'Correspondence recorded'
      else
        flash[:alert] = 'An unexpected error occurred with the correspondence'
      end
    end
    redirect_to(@tutorial || @name)
  end
end
