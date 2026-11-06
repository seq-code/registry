class Names::HistoriesController < ApplicationController
  before_action(:set_name)

  # GET /names/1/history
  def show
    @history = Name::PublicHistory.new(@name)
    @versions = @history.versions(page: params[:page])
    @crumbs = [['Names', names_path], [@name.abbr_name, @name], 'History']
  end

  private

  def set_name
    @name = Name.find(params[:name_id])
    render('names/hidden') unless @name.can_view?(current_user, cookies[:reviewer_token])
  end
end
