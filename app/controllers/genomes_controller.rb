class GenomesController < ApplicationController
  before_action(
    :set_genome,
    only: %i[show edit update update_external recalculate_miga]
  )
  before_action(:set_name, only: %i[show edit update])
  before_action(:set_tutorial)
  before_action(:authenticate_can_edit!, only: %i[edit update])
  before_action(
    :authenticate_curator!,
    only: %i[index update_external recalculate_miga]
  )

  # GET /genomes or /genomes.json
  def index
    @genomes = Genome.all
  end

  # GET /genomes/1 or /genomes/1.json
  def show
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

  # POST /genomes/1/update_external
  def update_external
    if @genome.queue_for_external_resources
      flash[:notice] = 'Update has been queued, please reload page soon'
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_genome
      @genome = Genome.find(params[:id])
    end

    def set_name
      @name = params[:name].present? ? Name.find(params[:name]) : @genome.names.first
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
