class PublicationNamesController < ApplicationController
  before_action :set_publication_name, only: %i[destroy]
  before_action :set_publication, only: %i[link_name link_name_commit]
  before_action(
    :authenticate_contributor!, only: %i[destroy link_name link_name_commit]
  )

  # DELETE /publication_names/1
  def destroy
    name = @publication_name.name
    publication = @publication_name.publication
    PublicationName.transaction do
      if name.proposed_in? publication
        name.update(proposed_in: nil)
      end
      if name.corrigendum_in? publication
        name.update(corrigendum_in: nil, corrigendum_from: nil)
      end
      if name.assigned_in? publication
        name.update(assigned_in: nil)
      end
      @publication_name.destroy
    end

    redirect_to(
      params[:from_name] ? name : publication,
      notice: 'The publication was unlinked from the name'
    )
  end

  # GET /publications/1/link_name
  def link_name
    @crumbs = [
      ['Publications', publications_path],
      [@publication.short_citation, @publication],
      'Link names'
    ]
    @publication_name = PublicationName.new(publication: @publication)
  end

  # POST /publications/1/link_name
  def link_name_commit
    @crumbs = [
      ['Publications', publications_path],
      [@publication.short_citation, @publication],
      'Link names'
    ]
    @name = Name.find_by(name: params[:publication_name][:name])
    @publication_name = PublicationName.new(
      publication: @publication, name: @name
    )
    if @publication_name.save
      flash[:notice] = 'Name linked to the publication'
      redirect_to @publication
    else
      render :link_name
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
