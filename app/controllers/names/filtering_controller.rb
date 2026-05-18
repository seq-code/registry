# frozen_string_literal: true

# Controller for filtering and listing names by status, user, or type.
class Names::FilteringController < Names::BaseController
  # GET /names/user
  # GET /names/user?user=abc
  def user
    @user = current_user
    if params[:user] && current_user&.admin?
      @user = User.find_by(username: params[:user])
    end
    params[:status] ||= 'all'
    index(where: { created_by: @user })
    render :index
  end

  # GET /names/observing
  def observing
    user = current_user
    if params[:user] && current_user.admin?
      user = User.find_by(username: params[:user])
    end
    @title  = 'Names with active alerts'
    @status = 'user'
    @names  = user.observing_names.reverse_order
    index
    render :index
  end

  # GET /names/submitted
  def submitted
    @submitted = true
    @status = 'submitted'
    index(status: 10)
    render :index
  end

  # GET /names/endorsed
  def endorsed
    @endorsed = true
    @status = 'endorsed'
    index(status: 12)
    render :index
  end

  # GET /names/draft
  def draft
    @draft = true
    @status = 'draft'
    index(status: 5)
    render :index
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

  # GET /type-genomes
  # GET /type-genomes.json
  def type_genomes
    @names = Name.where(status: 15, nomenclatural_type_type: :Genome)
                 .reorder(priority_date: :desc, updated_at: :desc)
                 .paginate(page: params[:page], per_page: 50)
    @crumbs = [['Genomes', genomes_path], 'Type']
  end

  private

  # Reuse the index logic from Names::MainController
  def index(opts = {})
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
end
