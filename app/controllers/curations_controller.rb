class CurationsController < ApplicationController
  before_action :authenticate_curator!
  before_action :set_curation, only: %i[update]

  # POST /curations
  def create
    @curation = Curation.new(curation_params)

    if @curation.save
      flash[:notice] = 'Curation tracking registered'
    else
      flash.now[:danger] = 'Curation tracking could not be registered'
    end
    redirect_back(fallback_location: @curation.name&.register)
  end

  # POST /curations/1
  def update
    if @curation.update(curation_params)
      flash[:notice] = 'Curation tracking registered'
    else
      flash.now[:danger] = 'Curation tracking could not be registered'
    end
    redirect_back(fallback_location: @curation.name&.register)
  end

  private
    def set_curation
      @curation = Curation.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def curation_params
      params
        .require(:curation)
        .permit(:name_id, :status_int, :kind_int, :notes)
        .merge(user: current_user)
    end
end
