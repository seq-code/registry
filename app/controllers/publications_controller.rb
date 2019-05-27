class PublicationsController < ApplicationController
  before_action :set_publication, only: [:show, :edit, :update, :destroy, :link_names, :link_names_commit]
  before_action :authenticate_contributor!, only: [:new, :edit, :create, :update, :destroy, :link_names, :link_names_commit]

  # GET /publications
  # GET /publications.json
  def index
    @publications = Publication.paginate(page: params[:page], per_page: 10)
    @crumbs = ['Publications']
  end

  # GET /publications/1
  # GET /publications/1.json
  def show
    @crumbs = [['Publications', publications_path], @publication.short_citation]
  end

  # GET /publications/new
  def new
    @publication = Publication.new
  end

  # GET /publications/1/edit
  def edit
  end

  # POST /publications
  def create
    @publication = Publication.by_doi(params['publication']['doi'])
    if @publication.new_record?
      render 'new'
    else
      redirect_to @publication
    end
  end

  # PATCH/PUT /publications/1
  # PATCH/PUT /publications/1.json
  def update
    respond_to do |format|
      if @publication.update(publication_params)
        format.html { redirect_to @publication, notice: 'Publication was successfully updated.' }
        format.json { render :show, status: :ok, location: @publication }
      else
        format.html { render :edit }
        format.json { render json: @publication.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /publications/1
  # DELETE /publications/1.json
  def destroy
    @publication.destroy
    respond_to do |format|
      format.html { redirect_to publications_url, notice: 'Publication was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_publication
      @publication = params[:id] ? Publication.find(params[:id]) :
        params[:doi] ? Publication.find_by(doi: params[:doi]) : nil
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def publication_params
      params.require(:publication).permit(:title, :journal, :journal_loc, :journal_date, :doi, :url, :pub_type, :crossref_json, :abstract)
    end
end
