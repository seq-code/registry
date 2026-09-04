class PublicationsController < ApplicationController
  before_action(
    :set_publication,
    only: %i[show edit update destroy names]
  )
  before_action(
    :authenticate_contributor!, only: %i[new edit create update destroy]
  )

  # GET /publications
  # GET /publications.json
  def index
    @sort = params[:sort]
    @publications =
      case @sort
      when 'names'
        Publication
          .left_joins(:publication_names).group(:id)
          .reorder('COUNT(publication_names.id) DESC')
      else
        @sort = 'date'
        Publication
      end
    @publications = @publications.paginate(page: params[:page], per_page: 10)

    @count = @publications.count
    @count = @count.size if @count.is_a? Hash
    @crumbs = ['Publications']
  end

  # GET /publications/1
  # GET /publications/1.json
  def show
    @crumbs = [['Publications', publications_path], @publication.short_citation]
  end

  # GET /publications/1/names
  def names
    render(layout: !params[:content].present?)
  end

  # GET /publications/new
  def new
    @publication = Publication.new
    @name = Name.find(params[:link_name]) if params[:link_name]
  end

  # GET /publications/1/edit
  def edit
  end

  # POST /publications
  def create
    if params['publication']['doi'].blank? && current_user.try(:curator?)
      @publication = Publication.new(publication_manual_params)
      return render('new') unless @publication.save
      @publication.add_authors(
        params[:authors_given].to_a.zip(params[:authors_family].to_a)
      )
    else
      doi = params['publication']['doi']
      # by_autocomplete resolves either a raw DOI (falling through to
      # by_doi, so "type a fresh DOI to register it" keeps working
      # unchanged) or a doi_title-style "key: title" string from selecting
      # an existing publication in the autocomplete dropdown — including a
      # DOI-less one via its "id:<id>" key. Only falls back to by_doi
      # directly for blank input, matching its pre-existing error message.
      @publication = Publication.by_autocomplete(doi) || Publication.by_doi(doi)
      return render('new') if @publication.new_record?
    end

    if params[:link_name] && params[:link_name][:id]
      @name = Name.find(params[:link_name][:id])
      par = { publication: @publication, name: @name }
      pn = PublicationName.find_or_create_by(par)

      case params[:link_name][:as]
      when 'propose'
        @name.update(proposed_in: @publication)
        flash[:notice] = 'Effective publication registered'
      when 'not_valid_proposal'
        pn.update(not_valid_proposal: true)
        flash[:notice] =
          'Original (not valid) publication registered'
      when 'corrig'
        redirect_to(
          corrigendum_in_name_url(@name, publication_id: @publication.id)
        )
        return
      when 'assign'
        @name.update(assigned_in: @publication)
        flash[:notice] = 'Taxonomic assignment publication registered'
      when 'emend'
        pn.update(emends: true)
        flash[:notice] = 'Emending publication registered'
      else
        flash[:notice] = 'Publication registered'
      end
      redirect_to(@name)
    else
      redirect_to(@publication)
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

  # GET /publications/autocomplete.json?q=List
  def autocomplete
    publication = params[:q].downcase
    @publications =
      Publication.where('LOWER(title) LIKE ?', "%#{publication}%")
          .or(Publication.where('LOWER(doi) LIKE ?', publication))
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_publication
      @publication = params[:id] ? Publication.find(params[:id]) :
        params[:doi] ? Publication.find_by(doi: params[:doi]) : nil
    end

    # Fields a curator may hand-enter to register a publication without a
    # DOI (e.g. an older paper never issued one). Deliberately excludes
    # crossref_json/datacite_json, which only ever hold verbatim external-API
    # payloads and have no place in a manually-entered record.
    def publication_manual_params
      params.require(:publication)
        .permit(*%i[title journal journal_loc journal_date doi url pub_type abstract])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def publication_params
      params.require(:publication)
        .permit(*%i[
          title journal journal_loc journal_date doi url pub_type
          crossref_json abstract
        ])
    end
end
