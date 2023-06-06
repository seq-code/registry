class ChecksController < ApplicationController
  before_action(:authenticate_curator!)

  # POST /checks/123.json
  def update
    unless Name.exists?(params[:name_id])
      return render(json: { error: 'unknown name' }, status: :not_found)
    end

    check_params = { name_id: params[:name_id], kind: params[:kind]}
    success = false
    @check = Check.where(check_params).first

    case params[:do]
    when 'skip'
      success = !@check || @check.destroy
    when 'pass', 'fail'
      @check ||= Check.new(check_params)
      @check.pass = params[:do] == 'pass'
      @check.user = current_user
      success = @check.save
    else
      return render(
        json: { error: 'unknown action: ' + params[:do] },
        status: :unprocessable_entity
      )
    end

    if success
      render(json: @check.to_json, status: :ok)
    else
      render(
        json: @check.try(:errors) || { error: 'something went wrong' },
        status: :unprocessable_entity
      )
    end
  end
end
