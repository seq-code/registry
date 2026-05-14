# frozen_string_literal: true

# Controller for publication-related actions on names.
class Names::PublicationsController < Names::BaseController
  # POST /names/1/proposed_in/2
  # POST /names/1/proposed_in/2?not=true
  def proposed_in
    @publication =
      params[:not] ? nil : Publication.where(id: params[:publication_id]).first
    @name.update(proposed_in: @publication)
    redirect_back(fallback_location: @name)
  end

  # POST /names/1/not_validly_proposed_in/2
  # POST /names/1/not_validly_proposed_in/2?not=true
  def not_validly_proposed_in
    @name.publication_names
      .where(publication_id: params[:publication_id])
      .update(not_valid_proposal: !params[:not])
    redirect_back(fallback_location: @name)
  end

  # GET /names/1/corrigendum_in
  # GET /names/1/corrigendum_in?publication_id=2
  def corrigendum_in
    @corrigendum_in_old = @name.corrigendum_in
    @publication = Publication.where(id: params[:publication_id]).first
    @name.corrigendum_in = @publication
  end

  # POST /names/1/assigned_in/2
  # POST /names/1/assigned_in/2?not=true
  def assigned_in
    @publication =
      params[:not] ? nil : Publication.where(id: params[:publication_id]).first
    @name.update(assigned_in: @publication)
    @name.placement.try(:update, publication: @publication)
    redirect_back(fallback_location: @name)
  end

  # POST /names/1/corrigendum
  def corrigendum
    par = params[:delete_corrigenda] ?
      { corrigendum_in_id: nil, corrigendum_from: nil } :
      params.require(:name).permit(
        :name, :corrigendum_in_id, :corrigendum_from, :corrigendum_kind
      )
    if @name.update(par)
      flash[:notice] = params[:delete_corrigenda] ?
        'Corrigendum removed successfully' :
        'Corrigendum successfully registered'
      redirect_to(name_path(@name))
    elsif params[:delete_corrigenda]
      flash[:alert] = 'Corrigendum could not be removed'
      redirect_to(name_path(@name))
    else
      flash.now[:alert] = 'There was an issue registering the corrigendum'
      params[:publication_id] = par[:corrigendum_in_id]
      render :corrigendum_in
    end
  end

  # POST /names/1/emended_in/2
  # POST /names/1/emended_in/2?not=true
  def emended_in
    @name.publication_names
      .where(publication_id: params[:publication_id])
      .update(emends: !params[:not])
    redirect_back(fallback_location: @name)
  end
end
