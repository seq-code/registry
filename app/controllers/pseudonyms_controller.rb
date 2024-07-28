class PseudonymsController < ApplicationController
  before_action(:set_pseudonym, only: %i[show edit update destroy])
  before_action(:set_name)
  before_action(:authenticate_can_edit!)

  # GET /names/3/pseudonyms/new
  def new
    @pseudonym = Pseudonym.new(name: @name)
  end

  # POST /names/3/pseudonyms
  # POST /names/3/pseudonyms.json
  def create
    @pseudonym = Pseudonym.new(pseudonym_params)
    @pseudonym.name ||= @name
    respond_to do |format|
      if @pseudonym.save
        @name.add_observer(current_user)
        format.html { redirect_to @name, notice: 'Pseudonym was successfully registered' }
        format.json { render :show, status: :created, location: @name }
      else
        format.html { render :new }
        format.json { render json: @pseudonym.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /names/3/pseudonyms/1/edit
  def edit
  end

  # PUT /names/3/pseudonyms/1
  # PUT /names/3/pseudonyms/1.json
  def update
    respond_to do |format|
      if @pseudonym.update(pseudonym_params.merge(name: @name))
        format.html { redirect_to(params[:return_to] || @name, notice: 'Pseudonym was successfully updated') }
        format.json { render(:show, status: :ok, location: @name) }
      else
        format.html { render(:edit) }
        format.json { render(json: @pseudonym.errors, status: :unprocessable_entity) }
      end
    end
  end

  # DELETE /names/3/pseudonyms/1
  # DELETE /names/3/pseudonyms/1.json
  def destroy
    @pseudonym.destroy
    respond_to do |format|
      format.html { redirect_to @name, notice: 'Pseudonym was successfully destroyed' }
      format.json { head :no_content }
    end
  end
  
  private

    def pseudonym_params
      params.require(:pseudonym)
        .permit(:name, :name_id, :pseudonym, :kind)
    end

    def set_pseudonym
      @pseudonym = Pseudonym.find(params[:id])
    end

    def set_name
      @name = @pseudonym&.name
      @name ||= Name.find(params[:name_id])
    end

    def authenticate_can_edit!
      unless @name&.can_edit_validated?(current_user)
        flash[:alert] = 'User cannot edit pseudonyms'
        redirect_to(root_path)
      end
    end
end
