# frozen_string_literal: true

# Controller for utility actions on names.
class Names::UtilityController < Names::BaseController
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

  # GET /names/etymology_sandbox
  def etymology_sandbox
    @name = Name.new(name: params[:name] || '')
  end

  # GET /names/syllabify?name=Abc
  def syllabify
    @name = Name.new(name: params[:name] || '')
    @syllabification = @name.guess_syllabication
  end

  # GET /names/1/quality_checks
  def quality_checks
    @crumbs = [
      ['Names', names_path],
      [@name.abbr_name, @name],
      'Quality Checks'
    ]
    render('quality_checks', layout: !params[:content].present?)
  end
end
