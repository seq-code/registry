class NamesController < ApplicationController
  before_action :set_name, only: [:show, :edit, :update, :destroy,
    :proposed_by, :emended_by, :edit_etymology,
    :link_parent, :link_parent_commit]
  before_action :authenticate_contributor!, only: [:new, :create, :edit,
    :update, :destroy, :proposed_by, :emended_by, :edit_etymology,
    :link_parent, :link_parent_commit]

  # GET /names
  # GET /names.json
  def index
    @sort = params[:sort]
    @names =
      case @sort
      when 'date'
        Name.order(created_at: :desc)
      when 'citations'
        Name
          .left_joins(:publication_names).group(:id)
          .order('COUNT(publication_names.id) DESC')
      else
        @sort = 'alphabetically'
        Name.order(name: :asc)
      end
    @names = @names.paginate(page: params[:page], per_page: 30)
    @crumbs = ['Names']
  end

  # GET /names/1
  # GET /names/1.json
  def show
    @publication_names = @name.publication_names.paginate(page: params[:page], per_page: 10)
    @oldest_publication = @name.publications.last
    @crumbs = [['Names', names_path], @name.abbr_name]
  end

  # GET /names/new
  def new
    @name = Name.new
  end

  # GET /names/1/edit
  def edit
  end

  # POST /names
  # POST /names.json
  def create
    @name = Name.new(name_params)

    respond_to do |format|
      if @name.save
        format.html { redirect_to @name, notice: 'Name was successfully created.' }
        format.json { render :show, status: :created, location: @name }
      else
        format.html { render :new }
        format.json { render json: @name.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /names/1
  # PATCH/PUT /names/1.json
  def update
    params[:name][:syllabication_reviewed] = true if name_params[:syllabication]
    respond_to do |format|
      if @name.update(name_params)
        format.html { redirect_to @name, notice: 'Name was successfully updated.' }
        format.json { render :show, status: :ok, location: @name }
      else
        format.html { render(name_params[:name] ? :edit : :edit_etymology) }
        format.json { render json: @name.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /names/1
  # DELETE /names/1.json
  def destroy
    @name.destroy
    respond_to do |format|
      format.html { redirect_to names_url, notice: 'Name was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  # POST /names/1/proposed_by?publication_id=2
  def proposed_by
    publication = Publication.where(id: params[:publication_id]).first
    @name.update(proposed_by: publication)
    redirect_back(fallback_location: @name)
  end

  # POST /names/1/emended_by/2
  # POST /names/1/emended_by/2?not=true
  def emended_by
    @name.publication_names
      .where(publication_id: params[:publication_id])
      .update(emends: !params[:not])
    redirect_back(fallback_location: @name)
  end

  # GET /names/1/link_parent
  def link_parent
  end

  # POST /names/1/link_parent
  def link_parent_commit
    parent = Name.find_by(name: params[:name][:parent])
    if @name.update(parent: parent)
      flash[:notice] = 'Parent linked to the name'
      redirect_to @name
    else
      render :link_parent
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_name
      @name = Name.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def name_params
      etymology_pars = Name.etymology_particles.map do |i|
        Name.etymology_fields.map { |j| :"etymology_#{i}_#{j}" }
      end.flatten
      params.require(:name)
        .permit(:name, :description, :syllabication, *etymology_pars)
    end
end
