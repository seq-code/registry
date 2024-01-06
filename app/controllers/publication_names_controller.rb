class PublicationNamesController < ApplicationController
  before_action :set_publication_name, only: [:show, :destroy]
  before_action :set_publication, only: [:link_names, :link_names_commit]
  before_action :authenticate_contributor!, only: [:destroy, :link_names, :link_names_commit]

  # GET /publication_names
  # GET /publication_names.json
  def index
    @publication_names = PublicationName.all
  end

  # GET /publication_names/1
  # GET /publication_names/1.json
  def show
  end

  # DELETE /publication_names/1
  def destroy
    name = @publication_name.name
    publication = @publication_name.publication
    PublicationName.transaction do
      if name.proposed_by? publication
        name.update(proposed_by: nil)
      end
      if name.corrigendum_by? publication
        name.update(corrigendum_by: nil, corrigendum_from: nil)
      end
      if name.assigned_by? publication
        name.update(assigned_by: nil)
      end
      @publication_name.destroy
    end

    redirect_to(
      params[:from_name] ? name : publication,
      notice: 'The publication was unlinked from the name'
    )
  end

  # GET /publications/1/link_names
  def link_names
    @crumbs = [['Publications', publications_path], [@publication.short_citation, @publication], 'Link names']
    @publication_name = PublicationName.new(publication: @publication)
  end

  # POST /publications/1/link_names
  def link_names_commit
    @crumbs = [['Publications', publications_path], [@publication.short_citation, @publication], 'Link names']
    @name = Name.find_by(name: params[:publication_name][:name])
    @publication_name = PublicationName.new(publication: @publication, name: @name)
    if @publication_name.save
      flash[:notice] = 'Name linked to the publication'
      redirect_to @publication
    else
      render :link_names
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_publication_name
      @publication_name = PublicationName.find(params[:id])
    end

    def set_publication
      @publication = Publication.find(params[:id])
    end
end
