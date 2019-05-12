class PublicationNamesController < ApplicationController
  before_action :set_publication_name, only: [:show, :edit, :update, :destroy]

  # GET /publication_names
  # GET /publication_names.json
  def index
    @publication_names = PublicationName.all
  end

  # GET /publication_names/1
  # GET /publication_names/1.json
  def show
  end

  # GET /publication_names/new
  def new
    @publication_name = PublicationName.new
  end

  # GET /publication_names/1/edit
  def edit
  end

  # POST /publication_names
  # POST /publication_names.json
  def create
    @publication_name = PublicationName.new(publication_name_params)

    respond_to do |format|
      if @publication_name.save
        format.html { redirect_to @publication_name, notice: 'Publication name was successfully created.' }
        format.json { render :show, status: :created, location: @publication_name }
      else
        format.html { render :new }
        format.json { render json: @publication_name.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /publication_names/1
  # PATCH/PUT /publication_names/1.json
  def update
    respond_to do |format|
      if @publication_name.update(publication_name_params)
        format.html { redirect_to @publication_name, notice: 'Publication name was successfully updated.' }
        format.json { render :show, status: :ok, location: @publication_name }
      else
        format.html { render :edit }
        format.json { render json: @publication_name.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /publication_names/1
  # DELETE /publication_names/1.json
  def destroy
    @publication_name.destroy
    respond_to do |format|
      format.html { redirect_to publication_names_url, notice: 'Publication name was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_publication_name
      @publication_name = PublicationName.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def publication_name_params
      params.require(:publication_name).permit(:publication_id, :name_id)
    end
end
