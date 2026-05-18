# frozen_string_literal: true

# Controller for core CRUD operations on Names.
class Names::NamesController < Names::BaseController
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
    return user if params[:user].present? && !opts[:where].present?

    @user      ||= nil
    @submitted ||= false
    @endorsed  ||= false
    @draft     ||= false
    @sort      ||= params[:sort] || 'date'
    @status    ||= params[:status] || 'public'
    @status      = 'ICNafp' if @status == 'ICN'
    @title     ||= [
      @status == 'all' ? nil : @status.gsub(/^\S/, &:upcase),
      'Names',
      @user.present? ? "by #{@user.username}" : nil
    ].compact.join(' ')
    opts[:rank] = params[:rank] if params[:rank].present?

    opts[:status] ||=
      case @status.to_s.downcase
      when 'public';    Name.public_status
      when 'automated'; 0
      when 'seqcode';   15
      when 'icnp';      20
      when 'icnafp';    25
      when 'valid';     Name.valid_status
      end

    @names ||=
      case @sort.to_s.downcase
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
    @crumbs = [['Names', names_path]]
    if @user.present?
      bu = "by #{@user.username}"
      if @status == 'all'
        @crumbs << bu
      else
        @crumbs << [bu, names_path(user: @user.username)]
        @crumbs << @status.gsub(/^\S/, &:upcase)
      end
    else
      if @status == 'public'
        @crumbs[0] = 'Names'
      else
        @crumbs << @status.gsub(/^\S/, &:upcase)
      end
    end
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
        response.set_header('Link', '<%s>; rel="canonical"' % url_for(@name))
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
end
