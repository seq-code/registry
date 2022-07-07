class TutorialsController < ApplicationController
  before_action :authenticate_contributor!
  before_action :set_tutorial, only: %i[ show update destroy ]
  before_action :set_name, only: %i[ show update ]

  # GET /tutorials
  def index
    @tutorials = current_user.tutorials
  end

  # GET /tutorials/1
  def show
    flash[:notice] = @tutorial.notice if @tutorial.notice
    if params[:next]
      params[:tutorial] = { id: @tutorial.id, next: true }
      update
    end
  end

  # POST /tutorials
  def create
    pipeline = params.require(:pipeline)
    par =  { pipeline: pipeline, user: current_user, step: 0, ongoing: true }
    @tutorial = Tutorial.new(par)

    if @tutorial.save
      flash[:notice] = 'Guided registration successfully initiated'
      redirect_to(@tutorial)
    else
      redirect_to(tutorials_url)
    end
  end

  # PATCH /tutorials/1
  def update
    if !params[:step_back].blank? && @tutorial.step > 0
      @tutorial.update(step: @tutorial.step - 1)
      redirect_to(@tutorial)
    elsif @tutorial.next_step(params.require(:tutorial), current_user)
      redirect_to(@tutorial.next_action, notice: @tutorial.notice)
    else
      render(:show)
    end
  end

  # DELETE /tutorials/1 or /tutorials/1.json
  def destroy
    @tutorial.destroy

    respond_to do |format|
      format.html { redirect_to tutorials_url, notice: 'Guided registration was successfully destroyed' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tutorial
      @tutorial = Tutorial.find(params[:id])
    end

    def set_name
      @name = @tutorial.current_name if @tutorial.value(:current_name_id)
      if @name
        @publication_names =
          @name.publication_names_ordered
               .paginate(page: params[:page], per_page: 10)
        @oldest_publication = @name.publications.last
      end
    end

    # Only allow a list of trusted parameters through.
    def tutorial_params
      params.require(:tutorial).permit(:pipeline, :ongoing, :step)
    end
end
