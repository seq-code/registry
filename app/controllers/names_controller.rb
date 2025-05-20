class NamesController < ApplicationController
  before_action(:set_tutorial)
  before_action(
    :set_name,
    only: %i[
      show edit update destroy network wiki
      proposed_in not_validly_proposed_in emended_in assigned_in
      corrigendum_in corrigendum_orphan corrigendum
      edit_description edit_rank edit_notes edit_etymology edit_links edit_type
      edit_redirect autofill_etymology edit_parent
      return validate endorse claim unclaim demote temporary_editable
      new_correspondence observe unobserve
    ]
  )
  before_action(
    :authenticate_can_edit!,
    only: %i[
      edit destroy
      proposed_in not_validly_proposed_in emended_in assigned_in
      corrigendum_in corrigendum_orphan corrigendum
      edit_description edit_rank edit_notes edit_etymology
      autofill_etymology edit_parent
    ]
  )
  before_action(:authenticate_can_edit_type!, only: [:edit_type])
  before_action(
    :authenticate_owner_or_curator!, only: %i[unclaim new_correspondence]
  )
  before_action(:authenticate_contributor!, only: %i[new create claim])
  before_action(:authenticate_admin!, only: %i[demote temporary_editable])
  before_action(
    :authenticate_curator!,
    only: %i[
      unranked unknown_proposal submitted endorsed draft
      return validate endorse edit_redirect
    ]
  )
  before_action(:authenticate_user!, only: %i[observe unobserve observing])
  before_action(:authenticate_can_edit_validated!, only: %i[update edit_links])

  # GET /names/autocomplete.json?q=Maco
  # GET /names/autocomplete.json?q=Allo&rank=genus
  def autocomplete
    name = params[:q].downcase
    rank = params[:rank]&.downcase
    @names =
      Name.where('LOWER(name) LIKE ?', "#{name}%")
          .or(Name.where('LOWER(name) LIKE ?', "% #{name}%"))
          .limit(20)
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
    opts[:rank] = params[:rank] if params[:rank].present?

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
    @names = @names.where(redirect: nil)
    @names = @names.where(status: opts[:status]) if opts[:status]
    @names = @names.where(rank: opts[:rank]) if opts[:rank]
    @names = @names.where(opts[:where]) if opts[:where]
    @names = @names.paginate(page: params[:page], per_page: 30)

    @count = @names.count
    @count = @count.size if @count.is_a? Hash
    @crumbs = ['Names']
  end

  # GET /type-genomes
  # GET /type-genomes.json
  def type_genomes
    @names = Name.where(status: 15, nomenclatural_type_type: :Genome)
                 .reorder(priority_date: :desc, updated_at: :desc)
                 .paginate(page: params[:page], per_page: 50)
    @crumbs = [['Genomes', genomes_path], 'Type']
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

  # GET /names/etymology_sandbox
  def etymology_sandbox
    @name = Name.new(name: params[:name] || '')
  end

  # GET /names/syllabify?name=Abc
  def syllabify
    @name = Name.new(name: params[:name] || '')
    @syllabification = @name.guess_syllabication
  end

  # GET /names/1
  # GET /names/1.json
  # GET /names/1.pdf
  def show
    if @name.redirect.present? && !params[:no_redirect]
      flash[:info] = 'Redirected from ' + @name.name
      redirect_to(name_url(@name.redirect, format: params[:format]))
      return
    end

    @publication_names =
      @name.publication_names_ordered
           .paginate(page: params[:page], per_page: 10)
    @oldest_publication = @name.publications.last
    @crumbs = [['Names', names_path], @name.abbr_name]
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

  # GET /names/linkout.xml
  # GET /names/1/linkout.xml
  def linkout
    @provider_id = Rails.configuration.try(:linkout_provider_id)
    unless @provider_id.present?
      @provider_id = 'Define using config.linkout_provider_id'
    end

    @names =
      params[:id] ?
        Name.where(id: params[:id]) :
        Name.where('status >= 15')
            .where.not(ncbi_taxonomy: nil)
            .order(created_at: :asc)
    @names =
      @names.paginate(
        page: params[:page] || 1, per_page: params[:per_page] || 10
      )
  end

  # GET /names/1/network
  def network
    respond_to do |format|
      format.html
      format.json do
        @nodes = @name.network_nodes
        @edges = @name.network_edges
      end
    end
  end

  # GET /names/1/wiki
  def wiki
    @crumbs = [['Names', names_path], [@name.name_html, @name], 'Wiki source']
    @name.check_wikispecies if current_user # Force re-check for logged users
  end

  # GET /names/new
  def new
    @name = Name.new
  end

  # GET /names/1/edit
  def edit
  end

  # GET /names/1/edit_description
  def edit_description
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

  # GET /names/1/edit_redirect
  def edit_redirect
  end

  # GET /names/1/autofill_etymology
  def autofill_etymology
    @name.autofill_etymology
    render(:edit_etymology)
  end

  # POST /names
  # POST /names.json
  def create
    @name = Name.new(status: 5, created_by: current_user)
    @name.assign_attributes(name_params)

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

    if name_params[:nomenclatural_type_type]&.==('Name')
      name_params[:genome_strain] = nil
    end

    if params[:edit].==('redirect')
      if name_params[:redirect].present?
        name_params[:redirect] = Name.find_by(name: name_params[:redirect])
        name_params[:status] = @name.status <= 15 ? 0 : @name.status
      else
        name_params[:redirect] = nil
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
      redirect_to(@name)
    elsif params[:delete_corrigenda]
      flash[:alert] = 'Corrigendum could not be removed'
      redirect_to(@name)
    else
      flash.now[:alert] = 'There was an issue registering the corrigendum'
      params[:publication_id] = par[:corrigendum_in_id]
      render(:corrigendum_in)
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

  # POST /names/1/demote
  def demote
    change_status(:demote, 'Name successfully demoted', current_user)
  end

  # POST /names/1/temporary_editable
  def temporary_editable
    to_time = DateTime.now + (params[:stop] ? 0 : 10.minutes)
    unless @name.update_column(:temporary_editable_at, to_time)
      flash[:alert] = 'Impossible to temporary update name'
    end
    redirect_to(@name)
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
      @register ||= @name.register
      @register.current_reviewer_token = cookies[:reviewer_token]
      current_user
        &.unseen_notifications
        &.where(notifiable: @name)
        &.update(seen: true)

      render 'hidden' unless @name.can_view?(current_user)
    end

    def set_tutorial
      return if params[:tutorial].blank?
      @tutorial = Tutorial.find(params[:tutorial])
    end

    def authenticate_owner_or_curator!
      unless current_user.try(:curator?) || @name.user?(current_user)
        flash[:alert] = 'User is not the owner of the name'
        redirect_to(@name)
      end
    end

    def authenticate_can_edit_validated!
      unless @name.can_edit_validated?(current_user)
        flash[:alert] = 'User cannot edit this aspect of the name'
        redirect_to(@name)
      end
    end

    def authenticate_can_edit_type!
      unless @name.can_edit_type?(current_user)
        flash[:alert] = 'User cannot edit the nomenclatural type'
        redirect_to(@name)
      end
    end

    def authenticate_can_edit!
      unless @name.can_edit?(current_user)
        flash[:alert] = 'User cannot edit name'
        redirect_to(@name)
      end
    end

    # Never trust parameters from the scary internet, only allow the white list
    # through
    def name_params
      fields = []
      if @name.can_edit_validated?(current_user)
        fields += %i[
          notes ncbi_taxonomy lpsn_url gtdb_accession algaebase_species
          algaebase_taxonomy
        ]
        unless @name.type?
          fields += %i[
            nomenclatural_type_type nomenclatural_type_id
            nomenclatural_type_entry
          ]
        end
      end

      if @name.can_edit?(current_user)
        fields += %i[
          name rank description syllabication syllabication_reviewed
          nomenclatural_type_type nomenclatural_type_id nomenclatural_type_entry
          etymology_text register genome_strain
        ] + etymology_pars
      end

      fields << :redirect if current_user.try(:curator?)

      @name_params ||= params.require(:name).permit(*fields.uniq)
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
