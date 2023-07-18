class PlacementsController < ApplicationController
  before_action(:set_placement, only: %i[edit update destroy prefer])
  before_action(:set_name)
  before_action(:authenticate_can_edit!)

  # GET /placements/new/123
  def new
    @placement = Placement.new(name_id: params[:name_id])
    @name = @placement.name or
      redirect_to(root_url, warning: 'Cannot create orphan placements')

    if params[:alt] && !@name.placement
      Placement.new(
        name: @name, preferred: true, parent: @name.parent,
        publication: @name.assigned_by,
        incertae_sedis: @name.incertae_sedis,
        incertae_sedis_text: @name.incertae_sedis_text
      ).save!
    end

    unless @name.placement
      @placement.parent = @name.parent
      @placement.publication = @name.assigned_by
      @placement.incertae_sedis = @name.incertae_sedis
      @placement.incertae_sedis_text = @name.incertae_sedis_text
      @placement.preferred = true
    end
  end

  # GET /placements/1
  def edit
  end

  # POST /placements
  def create
    @placement = Placement.new(
      params.require(:placement).permit(:name_id)
    )
    @name = @placement.name
    create_or_update(:new)
  end

  # PATCH/PUT /placements/1
  def update
    create_or_update(:edit)
  end

  def create_or_update(back_action)
    par = params.require(:placement).permit(
      :incertae_sedis, :incertae_sedis_text,
      :parent, :preferred, :publication
    )
    @placement.incertae_sedis = par[:incertae_sedis]
    @placement.incertae_sedis_text = par[:incertae_sedis_text]
    if @name.placement
      @placement.preferred = par[:preferred] if current_user.curator?
    else
      @placement.preferred = true
    end

    ok = true
    if par[:parent].present?
      if parent = Name.find_by(name: par[:parent])
        @placement.parent = parent
      else
        @placement.parent = Name.new(
          name: par[:parent], status: 5, created_by: current_user
        )
        unless @placement.parent.save
          flash[:alert] = 'Parent name could not be registered'
          @placement.errors.add(
            :parent, @placement.publication.errors.values.join(', ')
          )
          ok = false
        end
      end
    else
      @placement.parent = nil
    end

    if ok && par[:publication].present?
      doi = par[:publication].sub(/: .*/, '')
      @placement.publication = Publication.by_doi(doi)
      unless @placement.publication.persisted?
        flash[:alert] = 'Publication could not be registered'
        @placement.publication.doi = par[:publication]
        @placement.errors.add(
          :publication, @placement.publication.errors.values.join(', ')
        )
        ok = false
      end
    elsif ok
      @placement.publication = nil
    end

    if ok
      Placement.transaction do
        @placement.save!
        if @placement.publication &&
             !@name.publications.include?(@placement.publication)
          @name.publications << @placement.publication
        end
        if @placement.preferred
          old_placement = @name.placement
          if old_placement && @placement.id && old_placement.id != @placement.id
            old_placement.update!(preferred: false)
          end
          @name.update!(
            parent: @placement.parent, assigned_by: @placement.publication,
            incertae_sedis: nil, incertae_sedis_text: nil
          )
        end
      rescue
        ok = false
      end
    end

    if ok
      redirect_to(@name, notice: 'Placement successfully updated')
    else
      render(back_action, status: :unprocessable_entity)
    end
  end

  # POST /placements/1/prefer
  def prefer
    ok = false
    Placement.transaction do
      @name.placement.try(:update!, preferred: false)
      @placement.update!(preferred: true)
      @name.update!(
        parent: @placement.parent, assigned_by: @placement.publication,
        incertae_sedis: nil, incertae_sedis_text: nil
      )
      ok = true
    end

    if ok
      flash[:notice] = 'Preferred placement updated'
    elsif @placement.errors.any?
      flash[:warning] = 'Placement preference could not be updated: ' +
        @placement.errors.map { |k, v| "#{k} #{v}" }.join('; ')
    else
      flash[:warning] = 'Placement preference could not be updated'
    end

    redirect_to(@name)
  end

  # DELETE /placements/1
  def destroy
    Placement.transaction do
      @name.update(parent: nil, assigned_by: nil)
      @placement.destroy
    end
    redirect_to(@name, notice: 'Name placement was removed')
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_placement
      @placement = Placement.find(params[:id])
    end

    def set_name
      @name = @placement.try(:name) ||
        Name.find_by(id: params[:name_id] || params.dig(:placement, :name_id))
    end

    def authenticate_can_edit!
      unless @name.can_edit?(current_user)
        flash[:alert] = 'User cannot edit name'
        redirect_to(root_path)
      end
    end
end
