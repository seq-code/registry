# frozen_string_literal: true

# Controller for status-related actions on names.
class Names::StatusController < Names::BaseController
  # POST /names/1/return
  def return
    change_status(:return, 'Name returned to author', current_user)
  end

  # POST /names/1/validate
  def validate
    change_status(
      :validate, 'Name successfully validated', current_user, params[:code]
    )
  end

  # POST /names/1/endorse
  def endorse
    change_status(:endorse, 'Name successfully endorsed', current_user)
  end

  # POST /names/1/claim
  def claim
    change_status(:claim, 'Name successfully claimed', current_user)
  end

  # POST /names/1/unclaim
  def unclaim
    change_status(:unclaim, 'Name successfully unclaimed', current_user)
  end

  # POST /names/1/demote
  def demote
    change_status(:demote, 'Name successfully demoted', current_user)
  end

  # POST /names/1/temporary_editable
  def temporary_editable
    to_time = DateTime.now + (params[:stop] ? 0 : 10.minutes)
    unless @name.update_column(:temporary_editable_at, to_time)
      flash[:alert] = 'Impossible to temporary update name'
    end
    redirect_to(@name)
  end
end
