class ChecksController < ApplicationController
  before_action(:authenticate_curator!)
  before_action :set_check, only: %i[ update destroy ]

  # POST /checks or /checks.json
  def create
    @check = Check.new(check_params)

    respond_to do |format|
      if @check.save
        format.html { redirect_to check_url(@check), notice: "Check was successfully created." }
        format.json { render :show, status: :created, location: @check }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @check.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /checks/1 or /checks/1.json
  def update
    respond_to do |format|
      if @check.update(check_params)
        format.html { redirect_to check_url(@check), notice: "Check was successfully updated." }
        format.json { render :show, status: :ok, location: @check }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @check.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /checks/1 or /checks/1.json
  def destroy
    @check.destroy

    respond_to do |format|
      format.html { redirect_to checks_url, notice: "Check was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_check
      @check = Check.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def check_params
      params.require(:check).permit(:name_id, :user_id, :kind, :pass)
    end
end
