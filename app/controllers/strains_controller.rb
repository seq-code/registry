class StrainsController < ApplicationController
  before_action(:set_strain, only: %i[show strain_info])
  before_action(:set_name, only: %i[show strain_info])

  # GET /strains
  def index
    @strains = Strain.all.paginate(page: params[:page], per_page: 30)
  end

  # GET /strains/1
  def show
    @name ||= @strain.typified_names.first
    @crumbs = [['Strains', strains_url], @strain.title]
  end

  # GET /strains/1/strain_info
  def strain_info
    render('strain_info', layout: !params[:content].present?)
  end

  private

  def set_strain
    @strain = Strain.find(params[:id])
  end

  def set_name
    @name = Name.find(params[:name]) if params[:name]
  end
end

