class ApplicationController < ActionController::Base
  include PageHelper

  protect_from_forgery(with: :exception)
  before_action(:check_api!)
  before_action(:store_user_location!, if: :storable_location?)

  @@search_obj = {
    publications: [
      Publication, %i[title doi journal abstract journal_date], {
       PublicationAuthor.joins(:author) => %i[family publication_id]
      }
    ],
    authors: [Author, %i[given family], {}],
    names: [
      Name, %i[name corrigendum_from],
      {
        # TODO
        # This is ready to work, but it could return too much "trash", so
        # I'm holding off until we have advanced search options:
        # ActionText::RichText.where(record_type: 'Name') => %i[body record_id],
        Pseudonym => %i[pseudonym name_id]
      },
      { rank: :rank }
    ],
    subjects: [Subject, %i[name], {}]
  }

  def main
    @publications = Publication.all.order(journal_date: :desc)
    @authors = Author.all.order(created_at: :desc)
    @names = Name.where(status: [0, 15]).order(created_at: :desc)
    @validated = {
      names: Name.where(status: 15).order(validated_at: :desc),
      registers: Register.where(validated: true)
    }
  end

  def search
    if [:what, :q].any? { |i| params[i].nil? }
      render :search_query
    else
      @what = params[:what].to_sym
      if @@search_obj[@what]
        @q = params[:q]
        @results = search_by(@what, @q).paginate(
          page: params[:page],
          per_page: @what == :authors ? 100 : @what == :publications ? 10 : 30
        )
        redirect_to @results.first if @results.count == 1
      else
        flash[:danger] = 'Unsupported object.'
        redirect_to root_url
      end
    end
  end

  def search_query
  end

  # GET /set/list
  def set_list
    list_preference = cookies['list'] || 'cards'
    cookies.permanent[:list] = list_preference == 'cards' ? 'table' : 'cards'

    if params[:from] && RedirectSafely.safe?(params[:from])
      redirect_to(params[:from])
    else
      redirect_to(root_url)
    end
  end

  # GET /link/Patescibacteria
  # GET /link/Patescibacteria.json
  def short_link
    par = { format: params[:format] }
    super_pages = %w[initiative seqcode connect join committee prize]
    params[:path] ||= ''
    params[:path].sub!(%r[\A/+], '')
    params[:path].sub!(%r[(?<!/)/+\z], '')
    params[:path] = "p:#{params[:path]}" if params[:path].in? super_pages
    case path = params[:path]
    when *%w[robots sw favicon apple-touch-icon apple-touch-icon-precomposed]
      path += '.' + params[:format].gsub(/[^A-Z0-9]/i, '') if params[:format]
      redirect_to(File.join(root_path, path))
    when /\Ap:(.+)\z/
      redirect_to(page_path($1))
    when /\A(i:)?(\d+)\z/
      name = Name.where(id: $2).first or not_found
      redirect_to(name_path(name, par))
    when /\A(n:)?([a-z_\. ]+)\z/i
      name = Name.find_by_variants($2.gsub('_', ' ')) or not_found
      redirect_to(name_path(name, par))
    when /\A(r:.+)\z/i
      list = Register.where(accession: $1).first or not_found
      redirect_to(register_path(list, par))
    when /\Ag:(.+)\z/i
      genome = Genome.where(id: $1).first or not_found
      redirect_to(genome_path(genome, par))
    when /\Ah:(.+)\z/i
      redirect_to(help_path($1, par))
    when /\As:(\d+)\z/i
      strain = Strain.where(id: $1).first or not_found
      redirect_to(strain_path(strain, par))
    else
      redirect_to(root_path)
    end
  end

  def not_found
    raise ActionController::RoutingError.new('Not Found')
  end

  protected

    def authenticate_admin!
      authenticate_role! :admin?
    end

    def authenticate_contributor!
      authenticate_role! :contributor?
    end

    def authenticate_curator!
      authenticate_role! :curator?
    end

    def authenticate_editor!
      authenticate_role! :editor?
    end

    def authenticate_admin_or_curator!
      authenticate_admin! || authenticate_curator!
    end

    def authenticate_admin_curator_or_editor!
      authenticate_admin! || authenticate_curator! || authenticate_editor!
    end

  private

    def search_by(k, q)
      search = nil
      q.scan(/(?:\w|"[^"]*")+/).map do |term|
        and_term = search_by_term(k, term.gsub(/^"|"$/, ''))
        if search.nil?
          search = and_term
        else
          search = search.and(and_term)
        end
      end
      search
    end

    def search_by_term(k, q)
      obj = @@search_obj[k]
      o = obj[0].none
      q = q.strip

      if q =~ /^(\S+)::(.+)/ && obj[1].include?($1)
        # Search only in this field if specified (only for direct fields)
        o = o.or(search_by_field(obj[0], $1, $2.downcase))
      else
        q_like = "%#{q.downcase}%"

        # Search in direct fields
        obj[1].each do |i|
          o = o.or(search_by_field(obj[0], i, q_like))
        end

        # Search in relationships
        obj[2].each do |table, fields|
          o = o.or(
            obj[0].where(
              id: search_by_field(table, fields[0], q_like).pluck(fields[1])
            )
          )
        end
      end

      # Filter by additional parameters
      if obj[3].present?
        obj[3].each do |par, field|
          o = o.where(field => params[par]) if params[par].present?
        end
      end
      o
    end

    def search_by_field(table, field, value)
      case table.columns_hash[field.to_s].try(:type)
      when :date
        if ActiveRecord::Base.connection.instance_of?(
             ActiveRecord::ConnectionAdapters::SQLite3Adapter
           )
          table.where("#{field} LIKE ?", value)
        else
          table.where("to_char(#{field}, 'mm yyyy') LIKE ?", value)
        end
      else
        table.where("LOWER(#{field}) LIKE ?", value)
      end
    end

    def authenticate_role!(role)
      unless current_user.try(role)
        flash[:alert] = 'Action not allowed'
	redirect_to root_path
      end
    end

    def check_api!
      if Rails.configuration.try(:api_only)
        unless params[:format].to_s == 'json'
          redirect_to 'https://seqco.de/p:api'
        end
      end
    end

    def storable_location?
      request.get? && is_navigational_format? && !devise_controller? &&
        !request.xhr?
    end

    def store_user_location!
      store_location_for(:user, request.fullpath)
    end


end
