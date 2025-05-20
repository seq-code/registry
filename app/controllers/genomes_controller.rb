class GenomesController < ApplicationController
  before_action(
    :set_genome,
    only: %i[
      show edit update update_external update_accession recalculate_miga
      sample_map
    ]
  )
  before_action(:set_name, only: %i[show edit update update_accession])
  before_action(:set_tutorial)
  before_action(:authenticate_can_edit!, only: %i[edit update update_accession])
  before_action(
    :authenticate_curator!,
    only: %i[update_external recalculate_miga]
  )

  # GET /genomes or /genomes.json
  def index
    @genomes = Genome.all.order(created_at: :desc)
                     .paginate(page: params[:page], per_page: 30)
    @crumbs = ['Genomes']
  end

  # GET /genomes/1 or /genomes/1.json
  def show
    @register ||= @genome.names.first&.register
    @crumbs = [['Genomes', genomes_path], @genome.title('')]
  end

  # GET /genomes/1/edit
  def edit
  end

  # PATCH/PUT /genomes/1
  def update
    if @genome.update(genome_params.merge(updated_by: current_user))
        redirect_to(
          params[:return_to] || @name || @genome,
          notice: 'Genome was successfully updated.'
        )
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # PATCH /genomes/1/update_accession
  def update_accession
    par  = params.require(:genome).permit(:database, :accession)
    name = @genome.names.first
    if @genome.update_accession(par[:accession], par[:database])
      flash[:notice] = 'Genome successfully updated, ' \
                       'recalculate MiGA entry if needed'
    else
      flash[:alert] = 'Genome could not be updated'
    end
    redirect_back(fallback_location: @genome)
  end

  # POST /genomes/1/update_external
  def update_external
    if @genome.queue_for_external_resources(true) # Force: trust curators
      flash[:notice] = 'Update has been queued'
      sleep(2)
    else
      flash[:alert] = 'Update was not queued, something failed'
    end
    redirect_back(fallback_location: @genome)
  end

  # POST /genomes/1/recalculate_miga
  def recalculate_miga
    if @genome.recalculate_miga!
      flash[:notice] = 'The genome is now queued for recalculation'
    else
      flash[:alert] = 'Genome recalculation was not queued, something failed'
    end
    redirect_back(fallback_location: @genome)
  end

  # GET /genomes/1/sample_map
  def sample_map
    @crumbs = [['Genomes', genomes_url], [@genome.title(''), @genome], 'Map']
    @sample_set = @genome.sample_set
    render('sample_map', layout: !params[:content].present?)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_genome
      @genome = Genome.find(params[:id])
    end

    def set_name
      @name = params[:name].present? ?
                Name.find(params[:name]) : @genome.names.first
      if @name.can_view?(current_user) || cookies[:reviewer_token].present?
        @register = @name.try(:register)
        @register.current_reviewer_token = cookies[:reviewer_token] if @register
        @register = nil unless @name.can_view?(current_user)
      end
    end

    def set_tutorial
      return if params[:tutorial].blank?
      @tutorial = Tutorial.find(params[:tutorial])
    end

    # Only allow a list of trusted parameters through.
    def genome_params
      params
        .require(:genome)
        .permit(*%i[
          kind seq_depth source_database source_accession gc_content
          completeness contamination most_complete_16s number_of_16s
          most_complete_23s number_of_23s number_of_trnas
          submitter_comments
        ])
    end

    def authenticate_can_edit!
      unless @genome.can_edit?(current_user)
        flash[:alert] = 'User cannot edit genome'
        redirect_to(root_path)
      end
    end

end
