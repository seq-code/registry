class StrainsController < ApplicationController
  before_action(
    :set_strain,
    only: %i[show strain_info link_genome link_genome_commit unlink_genome]
  )
  before_action(:set_name, only: %i[show strain_info])
  before_action(
    :authenticate_can_edit!,
    only: %i[link_genome link_genome_commit unlink_genome]
  )

  # GET /strains
  def index
    @strains = Strain.all.paginate(page: params[:page], per_page: 30)
    @crumbs  = ['Strains']
  end

  # GET /strains/1
  def show
    @name ||= @strain.typified_names.first
    @name ||= @strain.referenced_names.first
    @crumbs = [['Strains', strains_url], @strain.title]
  end

  # GET /strains/1/strain_info
  def strain_info
    render('strain_info', layout: !params[:content].present?)
  end

  # GET /strains/1/link_genome
  def link_genome
    @crumbs = [
      ['Strains', strains_url], [@strain.title, @strain], 'Link genome'
    ]
    @genome = Genome.new
    if params[:genome]
      @genome = Genome.find(params[:genome])
    else
      @genome.database = params[:database]
      @genome.accession = params[:accession]
      @genome.kind = 'isolate'
    end
  end

  # POST /strains/1/link_genome_commit
  def link_genome_commit
    par = params.require(:genome).permit(:database, :accession, :kind)
    @genome = Genome.find_or_create(par[:database], par[:accession])
    @genome.kind = par[:kind] if @genome.can_edit?(current_user)
    if @genome.save
      @strain.genomes << @genome
      flash[:notice] = 'Genome linked to the strain'
      redirect_to(@strain)
    else
      render :link_genome
    end
  end

  # POST /strains/1/unlink_genome
  def unlink_genome
    @genome = Genome.find(params.require(:genome))
    if @strain.genomes.delete(@genome)
      flash[:notice] = 'Genome unlinked from the strain'
    end
    redirect_to(@strain)
  end

  private

  def set_strain
    @strain = Strain.find(params[:id])
  end

  def set_name
    @name = Name.find(params[:name]) if params[:name]
    @register ||= @name.try(:register)
    @register.current_reviewer_token = cookies[:reviewer_token] if @register
  end

  def authenticate_can_edit!
    unless @strain.can_edit?(current_user)
      flash[:alert] = 'User cannot edit strain'
      redirect_to(@strain)
    end
  end
end

