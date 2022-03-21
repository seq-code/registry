class TutorialsController < ApplicationController
  before_action :authenticate_contributor!
  before_action :set_tutorial, only: %i[ show destroy ]

  # GET /tutorials
  def index
    @tutorials = current_user.tutorials
  end

  # GET /tutorials/1
  def show
  end

  # GET /tutorials/new
  def new
  end

  # POST /tutorials or /tutorials.json
  def create
    @tutorial = Tutorial.new(tutorial_params.merge(user: current_user))

    respond_to do |format|
      if @tutorial.save
        format.html { redirect_to tutorial_url(@tutorial), notice: "Tutorial was successfully created." }
        format.json { render :show, status: :created, location: @tutorial }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @tutorial.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tutorials/1 or /tutorials/1.json
  def destroy
    @tutorial.destroy

    respond_to do |format|
      format.html { redirect_to tutorials_url, notice: "Tutorial was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tutorial
      @tutorial = Tutorial.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def tutorial_params
      params.require(:tutorial).permit(:pipeline, :ongoing, :step)
    end
end
