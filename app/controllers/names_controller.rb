class NamesController < ApplicationController
  before_action(:set_tutorial)
  before_action(
    :set_name,
    only: %i[
      show edit update destroy proposed_by corrigendum_by corrigendum emended_by
      edit_rank edit_notes edit_etymology edit_links edit_type
      autofill_etymology link_parent link_parent_commit
      return validate approve claim unclaim new_correspondence
    ]
  )
  before_action(
    :authenticate_can_edit!,
    only: %i[
      edit update destroy proposed_by corrigendum_by corrigendum emended_by
      edit_rank edit_notes edit_etymology edit_links edit_type
      autofill_etymology link_parent link_parent_commit new_correspondence
    ]
  )
  before_action(:authenticate_owner_or_curator!, only: %i[unclaim])
  before_action(:authenticate_contributor!, only: %i[new create claim])
  before_action(
    :authenticate_curator!,
    only: %i[
      check_ranks unknown_proposal submitted drafts return validate approve
    ]
  )

  # GET /autocomplete_names.json?q=Maco
  # GET /autocomplete_names.json?q=Allo&rank=genus
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
    return user_names if params[:status] == 'user' && opts == {}
    @submitted ||= false
    @drafts    ||= false
    @sort      ||= params[:sort] || 'date'
    @status    ||= params[:status] || 'public'
    @title     ||=
      if @submitted
        'Review Submitted'
      elsif @drafts
        'Review Drafts'
      else
        "#{@status.gsub(/^\S/, &:upcase)} Names"
      end

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
      when 'valid'
        Name.valid_status
      end

    @names =
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
    @names = @names.where(status: opts[:status])
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

  # GET /user-names
  def user_names
    user = current_user
    if params[:user] && current_user.admin?
      user = User.find_by(username: params[:user])
    end
    @title = "Names by #{user.username}"
    @status = 'user'
    index(where: { created_by: user }, status: Name.status_hash.keys)
    render(:index)
  end

  # GET /submitted
  def submitted
    @submitted = true
    @status = 'submitted'
    index(status: 10)
    render(:index)
  end

  # GET /drafts
  def drafts
    @drafts = true
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
    @name.status = 5 # All new names begin as drafts
    @name.created_by = current_user

    respond_to do |format|
      if @name.save
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
    params[:name][:syllabication_reviewed] = true if name_params[:syllabication]
    params[:name][:register] = nil if name_params[:register]&.==('')

    if name_params[:type_material]&.==('name')
      acc = name_params[:type_accession]
      type_name =
        if acc.empty?
          nil
        elsif acc =~ /\A[0-9]+\z/
          Name.where(id: acc).first
        else
          Name.where(name: acc).first
        end
      params[:name][:type_accession] = type_name&.id

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

  # GET /check_ranks
  def check_ranks
    @names = Name.where(rank: nil).order(created_at: :asc)
    @names = @names.paginate(page: params[:page], per_page: 30)
  end

  # GET /unknown_proposal
  def unknown_proposal
    @names = Name.where(proposed_by: nil).where('name LIKE ?', 'Candidatus %').order(created_at: :asc)
    @names = @names.paginate(page: params[:page], per_page: 30)
  end

  # POST /names/1/proposed_by?publication_id=2
  def proposed_by
    publication = Publication.where(id: params[:publication_id]).first
    @name.update(proposed_by: publication)
    redirect_back(fallback_location: @name)
  end

  # GET /names/1/corrigendum_by?publication_id=2
  def corrigendum_by
    @publication = Publication.where(id: params[:publication_id]).first
    if @publication.nil?
      @name.update(corrigendum_by: nil, corrigendum_from: nil)
      redirect_back(fallback_location: @name)
    else
      @name.corrigendum_by = @publication
    end
  end

  # POST /names/1/corrigendum
  def corrigendum
    par = params.require(:name).permit(:corrigendum_by, :corrigendum_from)
    par[:corrigendum_by] = Publication.find(par[:corrigendum_by])
    @name.update(par)
    redirect_to(@name)
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
    par = params.require(:name).permit(
      :parent, :incertae_sedis, :incertae_sedis_text
    )

    ok = true
    if par[:parent].present?
      if parent = Name.find_by(name: par[:parent])
        par[:parent] = parent
      else
        par[:parent] = Name.new(
          name: par[:parent], status: 5, created_by: current_user
        )
        unless par[:parent].save
          flash[:alert] = 'Parent name could not be registered'
          @name.errors.add(:parent, par[:parent].errors.values.join(', '))
          ok = false
        end
      end
    else
      par[:parent] = nil
    end

    if ok && @name.update(par)
      flash[:notice] = 'Parent successfully updated'
      redirect_to(@name)
    else
      render(:link_parent)
    end
  end

  # POST /names/1/return
  def return
    par = { status: 5 }
    if !@name.after_submission?
      flash[:alert]  = 'Name status is incompatible with return'
    elsif @name.update(par)
      # Email notification
      AdminMailer.with(
        user: @name.created_by,
        name: @name,
        action: 'return'
      ).name_status_email.deliver_later
      flash[:notice] = 'Name returned to author'
    else
      flash[:alert]  = 'An unexpected error occurred'
    end
    redirect_to(@name)
  end

  # POST /names/1/validate
  def validate
    if params[:code] == 'icnp'
      par = {
        status: 20, validated_by: current_user, validated_at: Time.now
      }
      if @name.validated?
        flash[:alert] = 'Name status is incompatible with validation'
      elsif @name.update(par)
        # Email notification
        AdminMailer.with(
          user: @name.created_by,
          name: @name,
          action: 'validate'
        ).name_status_email.deliver_later
        flash[:notice] = 'Name successfully validated'
      else
        flash[:alert] = 'An unexpected error occurred'
      end
    else
      flash[:alert] =
        'Invalid procedure for nomenclatural code ' + params[:code]
    end
    redirect_to(@name)
  end

  # POST /names/1/approve
  def approve
    par = { status: 12, approved_by: current_user, approved_at: Time.now }
    if @name.after_approval?
      flash[:alert] = 'Name status is incompatible with approval'
    elsif @name.update(par)
      # Email notification
      AdminMailer.with(
        user: @name.created_by,
        name: @name,
        action: 'approve'
      ).name_status_email.deliver_later
      flash[:notice] = 'Name successfully approved'
    else
      flash[:alert] = 'An unexpected error occurred'
    end
    redirect_to(@name)
  end

  # POST /names/1/claim
  def claim
    if !@name.can_claim?(current_user)
      flash[:alert]  = 'You cannot claim this name'
    elsif @name.claim(current_user)
      flash[:notice] = 'Name successfully claimed'
    else
      flash[:alert]  = 'An unexpected error occurred'
    end
    redirect_to(@name)
  end

  # POST /names/1/unclaim
  def unclaim
    par = { status: 0 }
    if !@name.can_unclaim?(current_user)
      flash[:alert]  = 'You cannot unclaim this name'
    elsif @name.unclaim(current_user)
      flash[:notice] = 'Name successfully returned to the public pool'
    else
      flash[:alert]  = 'An unexpected error occurred'
    end
    redirect_to(@name)
  end

  # POST /names/1/new_correspondence
  def new_correspondence
    @name_correspondence = NameCorrespondence.new(
      params.require(:name_correspondence).permit(:message)
    )
    unless @name_correspondence.message.empty?
      @name_correspondence.user = current_user
      @name_correspondence.name = @name
      if @name_correspondence.save
        flash[:notice] = 'Correspondence recorded'
      else
        flash[:alert] = 'An unexpected error occurred with the correspondence'
      end
    end
    redirect_to(@tutorial || @name)
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

    # Never trust parameters from the scary internet, only allow the white list through.
    def name_params
      etymology_pars =
        Name.etymology_particles.map do |i|
          Name.etymology_fields.map { |j| :"etymology_#{i}_#{j}" }
        end.flatten

      params.require(:name)
        .permit(
          :name, :rank, :description, :notes, :ncbi_taxonomy,
          :syllabication, :syllabication_reviewed,
          :type_material, :type_accession, :etymology_text, :register,
           *etymology_pars
        )
    end
end
