class NamesController < ApplicationController
  before_action(:set_tutorial)
  before_action(
    :set_name,
    only: %i[
      show edit update destroy
      proposed_in emended_in assigned_in
      corrigendum_in corrigendum_orphan corrigendum
      edit_rank edit_notes edit_etymology edit_links edit_type
      autofill_etymology edit_parent
      return validate endorse claim unclaim new_correspondence
      observe unobserve
    ]
  )
  before_action(
    :authenticate_can_edit!,
    only: %i[
      edit update destroy
      proposed_in emended_in assigned_in
      corrigendum_in corrigendum_orphan corrigendum
      edit_rank edit_notes edit_etymology edit_links edit_type
      autofill_etymology edit_parent new_correspondence
    ]
  )
  before_action(:authenticate_owner_or_curator!, only: %i[unclaim])
  before_action(:authenticate_contributor!, only: %i[new create claim])
  before_action(
    :authenticate_curator!,
    only: %i[
      unranked unknown_proposal submitted endorsed draft
      return validate endorse
    ]
  )
  before_action(:authenticate_user!, only: %i[observe unobserve observing])

  # GET /names/autocomplete.json?q=Maco
  # GET /names/autocomplete.json?q=Allo&rank=genus
  def autocomplete
    name = params[:q].downcase
    rank = params[:rank]&.downcase
    @names =
      Name.where('LOWER(name) LIKE ?', "#{name}%")
          .or(Name.where('LOWER(name) LIKE ?', "% #{name}%"))
    @names = @names.where(rank: rank) if rank
  end

  # GET /names
  # GET /names.json
  def index(opts = {})
    return user if params[:status] == 'user' && opts == {}
    @submitted ||= false
    @endorsed  ||= false
    @draft     ||= false
    @sort      ||= params[:sort] || 'date'
    @status    ||= params[:status] || 'public'
    @title     ||= "#{@status.gsub(/^\S/, &:upcase)} Names"

    opts[:status] ||=
      case @status
      when 'public'
        Name.public_status
      when 'automated'
        0
      when 'SeqCode'
        15
      when 'ICNP'
        20
      when 'ICN'
        25
      when 'valid'
        Name.valid_status
      end

    @names ||=
      case @sort
      when 'date'
        if opts[:status] == 15
          Name.order(validated_at: :desc)
        else
          Name.order(created_at: :desc)
        end
      when 'citations'
        Name
          .left_joins(:publication_names).group(:id)
          .order('COUNT(publication_names.id) DESC')
      else
        @sort = 'alphabetically'
        Name.order(name: :asc)
      end
    @names = @names.where(status: opts[:status]) if opts[:status]
    @names = @names.where(opts[:where]) if opts[:where]
    @names = @names.paginate(page: params[:page], per_page: 30)

    @count = @names.count
    @count = @count.size if @count.is_a? Hash
    @crumbs = ['Names']
  end

  # GET /type-genomes
  # GET /type-genomes.json
  def type_genomes
    @names = Name.where(status: 15, type_material: :nuccore)
                 .or(Name.where(status: 15, type_material: :assembly))
                 .paginate(page: params[:page], per_page: 100)
  end

  # GET /names/user
  def user
    user = current_user
    if params[:user] && current_user.admin?
      user = User.find_by(username: params[:user])
    end
    @title  = "Names by #{user.username}"
    @status = 'user'
    index(where: { created_by: user })
    render(:index)
  end

  # GET /names/observing
  def observing
    user = current_user
    if params[:user] && current_user.admin?
      user = User.find_by(username: params[:user])
    end
    @title  = 'Names with active alerts'
    @status = 'user'
    @names  = user.observing_names.reverse
    index
    render(:index)
  end

  # GET /names/submitted
  def submitted
    @submitted = true
    @status = 'submitted'
    index(status: 10)
    render(:index)
  end

  # GET /names/endorsed
  def endorsed
    @endorsed = true
    @status = 'endorsed'
    index(status: 12)
    render(:index)
  end

  # GET /names/draft
  def draft
    @draft = true
    @status = 'draft'
    index(status: 5)
    render(:index)
  end

  # GET /names/1
  # GET /names/1.json
  # GET /names/1.pdf
  def show
    @publication_names =
      @name.publication_names_ordered
           .paginate(page: params[:page], per_page: 10)
    @oldest_publication = @name.publications.last
    @crumbs = [['Names', names_path], @name.abbr_name]
    @register ||= @name.register
    respond_to do |format|
      format.html
      format.json
      format.pdf do
        render(
          template: 'names/show_pdf.html.erb',
          pdf: "#{@name.name} | SeqCode Registry",
          header: { html: { template: 'layouts/_pdf_header' } },
          footer: { html: { template: 'layouts/_pdf_footer' } },
          page_size: 'A4'
        )
      end
    end
  end

  # GET /names/new
  def new
    @name = Name.new
  end

  # GET /names/1/edit
  def edit
  end

  # GET /names/1/edit_notes
  def edit_notes
  end

  # GET /names/1/edit_rank
  def edit_rank
  end

  # GET /names/1/edit_links
  def edit_links
  end

  # GET /names/1/edit_type
  def edit_type
    unless @name.rank?
      flash[:alert] = 'You must define the rank before the type material'
      redirect_to(@name)
    end
  end

  # GET /names/1/autofill_etymology
  def autofill_etymology
    @name.autofill_etymology
    render(:edit_etymology)
  end

  # POST /names
  # POST /names.json
  def create
    @name = Name.new(name_params)
    @name.status = 5 # All new names begin as draft
    @name.created_by = current_user

    respond_to do |format|
      if @name.save
        @name.add_observer(current_user)
        format.html { redirect_to @name, notice: 'Name was successfully created' }
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
    name_params[:syllabication_reviewed] = true if name_params[:syllabication]
    name_params[:register] = nil if name_params[:register]&.==('')

    if name_params[:type_material]&.==('name')
      name_params[:genome_strain] = nil
      acc = name_params[:type_accession]
      type_name =
        if acc.empty?
          nil
        elsif acc =~ /\A[0-9]+\z/
          Name.where(id: acc).first
        else
          Name.where(name: acc).first
        end
      name_params[:type_accession] = type_name.try(:id)

      if !acc.empty? && type_name.nil?
        flash[:alert] = 'Type name does not exist'
      end
    end

    respond_to do |format|
      if @name.update(name_params)
        format.html { redirect_to(params[:return_to] || @name, notice: 'Name was successfully updated') }
        format.json { render(:show, status: :ok, location: @name) }
      else
        format.html { render(name_params[:name] ? :edit : :edit_etymology) }
        format.json { render(json: @name.errors, status: :unprocessable_entity) }
      end
    end
  end

  # DELETE /names/1
  # DELETE /names/1.json
  def destroy
    @name.destroy
    respond_to do |format|
      format.html { redirect_to names_url, notice: 'Name was successfully destroyed' }
      format.json { head :no_content }
    end
  end

  # GET /names/unranked
  def unranked
    @names = Name.where(rank: nil).order(created_at: :asc)
    @names = @names.paginate(page: params[:page], per_page: 30)
  end

  # GET /names/unknown_proposal
  def unknown_proposal
    @names = Name.where(proposed_in: nil).where('name LIKE ?', 'Candidatus %').order(created_at: :asc)
    @names = @names.paginate(page: params[:page], per_page: 30)
  end

  # POST /names/1/proposed_in/2
  # POST /names/1/proposed_in/2?not=true
  def proposed_in
    @publication =
      params[:not] ? nil : Publication.where(id: params[:publication_id]).first
    @name.update(proposed_in: @publication)
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
      params.require(:name).permit(:name, :corrigendum_in_id, :corrigendum_from)
    @name.update(par)
    redirect_to(@name)
  end

  # POST /names/1/emended_in/2
  # POST /names/1/emended_in/2?not=true
  def emended_in
    @name.publication_names
      .where(publication_id: params[:publication_id])
      .update(emends: !params[:not])
    redirect_back(fallback_location: @name)
  end

  # GET /names/1/edit_parent
  def edit_parent
    if @name.placement
      redirect_to(edit_placement_path(@name.placement))
    else
      redirect_to(new_placement_path(@name))
    end
  end

  # POST /names/1/return
  def return
    change_status(:return, 'Name returned to author', current_user)
  end

  # POST /names/1/validate
  def validate
    change_status(
      :validate, 'Name successfully validated', current_user, params[:code]
    )
  end

  # POST /names/1/endorse
  def endorse
    change_status(:endorse, 'Name successfully endorsed', current_user)
  end

  # POST /names/1/claim
  def claim
    change_status(:claim, 'Name successfully claimed', current_user)
  end

  # POST /names/1/unclaim
  def unclaim
    change_status(:unclaim, 'Name successfully claimed', current_user)
  end

  # POST /names/1/new_correspondence
  def new_correspondence
    @name_correspondence = NameCorrespondence.new(
      params.require(:name_correspondence).permit(:message, :notify)
    )
    unless @name_correspondence.message.empty?
      @name_correspondence.user = current_user
      @name_correspondence.name = @name
      if @name_correspondence.save
        @name.add_observer(current_user)
        flash[:notice] = 'Correspondence recorded'
      else
        flash[:alert] = 'An unexpected error occurred with the correspondence'
      end
    end
    redirect_to(@tutorial || @name)
  end

  # GET /names/1/observe
  def observe
    @name.add_observer(current_user)
    if params[:from] && RedirectSafely.safe?(params[:from])
      redirect_to(params[:from])
    else
      redirect_back(fallback_location: @name)
    end
  end

  # GET /names/1/unobserve
  def unobserve
    @name.observers.delete(current_user)
    if params[:from] && RedirectSafely.safe?(params[:from])
      redirect_to(params[:from])
    else
      redirect_back(fallback_location: @name)
    end
  end

  private

    # Use callbacks to share common setup or constraints between actions
    def set_name
      @name = Name.find(params[:id])

      unless @name.can_see?(current_user)
        flash[:alert] = 'User cannot access name'
        redirect_to(root_path)
      end
    end

    def set_tutorial
      return if params[:tutorial].blank?
      @tutorial = Tutorial.find(params[:tutorial])
    end

    def authenticate_owner_or_curator!
      unless current_user.try(:curator?) || @name.user?(current_user)
        flash[:alert] = 'User is not the owner of the name'
        redirect_to(root_path)
      end
    end

    def authenticate_can_edit!
      unless @name.can_edit?(current_user)
        flash[:alert] = 'User cannot edit name'
        redirect_to(root_path)
      end
    end

    # Never trust parameters from the scary internet, only allow the white list
    # through
    def name_params
      @name_params ||=
        params.require(:name)
          .permit(
            :name, :rank, :description, :notes, :ncbi_taxonomy,
            :syllabication, :syllabication_reviewed,
            :type_material, :type_accession, :etymology_text, :register,
            :genome_strain,
            *etymology_pars
          )
    end

    def etymology_pars
      Name.etymology_particles.map do |i|
        Name.etymology_fields.map { |j| :"etymology_#{i}_#{j}" }
      end.flatten
    end

    def change_status(fun, success_msg, *extra_opts)
      if @name.send(fun, *extra_opts)
        flash[:notice] = success_msg
      else
        flash[:alert] = @name.status_alert
      end
      redirect_to(@name)
    rescue ActiveRecord::RecordInvalid => inv
      flash['alert'] =
        'An unexpected error occurred while updating the name: ' +
        inv.record.errors.map { |e| "#{e.attribute} #{e.message}" }.to_sentence
      redirect_to(inv.record)
    end
end
