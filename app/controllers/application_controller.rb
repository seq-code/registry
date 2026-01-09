class ApplicationController < ActionController::Base
  include PageHelper

  protect_from_forgery(with: :exception)
  before_action(:check_api!)
  before_action(:store_user_location!, if: :storable_location?)

  rescue_from ActionController::InvalidAuthenticityToken do |exception|
    logger.error "[CSRF ERROR] IP: #{request.remote_ip}, " \
                 "UA: #{request.user_agent}, " \
                 "Params: #{params.to_unsafe_h}, " \
                 "Session: #{session.to_hash}"
    raise
  end

  @@search_obj = {
    publications: [
      Publication, %i[title doi journal abstract journal_date], {
       PublicationAuthor.joins(:author) => %i[family publication_id]
      }
    ],
    authors: [Author, %i[given family], {}],
    names: [
      Name, %i[name corrigendum_from gtdb_accession],
      {
        # TODO
        # This is ready to work, but it could return too much "trash", so
        # I'm holding off until we have advanced search options:
        # ActionText::RichText.where(record_type: 'Name') => %i[body record_id],
        Pseudonym => %i[pseudonym name_id]
      },
      { rank: :rank }
    ],
    genomes: [Genome, %i[accession source_accession source_json], {}],
    subjects: [Subject, %i[name], {}]
  }

  # GET /
  def main2
    @services = {
      validly_published: Name.where(status: 15).order(validated_at: :desc),
      names: Name.all_public.order(created_at: :desc),
      publications: Publication.all.order(journal_date: :desc),
      register_lists: Register.where(validated: true).order(updated_at: :desc),
      genomes: Genome.all.order(created_at: :desc),
      strains: Strain.all.order(created_at: :desc)
    }
    @display = {
      validly_published:
               [:abbr_name, [:names_path, sort: :date, status: :SeqCode]],
      names:   [:abbr_name, [:names_path, sort: :date]],
      publications:
               [:short_citation, [:publications_path, sort: :date]],
      register_lists:
               [:acc_url, [:registers_path, status: :validated]],
      genomes: [:text, :genomes_path],
      strains: [:title, :strains_path]
    }
  end

  def main
    @publications = Publication.all.order(journal_date: :desc)
    @authors = Author.all.order(created_at: :desc)
    @names = Name.where(status: Name.public_status).order(created_at: :desc)
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
      name = Name.find_by_variants($2) or not_found
      redirect_to(name_path(name, par))
    when /\A(r:.+)\z/i
      list = Register.where(accession: $1).first or not_found
      redirect_to(register_path(list, par))
    when /\Ag:(\d+)\z/i
      genome = Genome.where(id: $1).first or not_found
      redirect_to(genome_path(genome, par))
    when /\Ag:([a-z]+):(.+)\z/i
      db, acc = [$1, $2]
      if par[:format].present? # Interpret as version, not as format
        acc += '.' + par[:format]
        par.delete(:format)
      end
      genome = Genome.where(database: db, accession: acc).first or not_found
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
        if ActiveRecord::Base.connection.adapter_name.downcase == 'sqlite'
          table.where("#{field} LIKE ?", value)
        else
          table.where("to_char(#{field}, 'YYYY-MM-DD') LIKE ?", value)
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
