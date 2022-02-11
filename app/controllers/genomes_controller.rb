class GenomesController < ApplicationController
  before_action :set_genome, only: %i[ show edit update destroy ]

  # GET /genomes or /genomes.json
  def index
    @genomes = Genome.all
  end

  # GET /genomes/1 or /genomes/1.json
  def show
  end

  # GET /genomes/new
  def new
    @genome = Genome.new
  end

  # GET /genomes/1/edit
  def edit
  end

  # POST /genomes or /genomes.json
  def create
    @genome = Genome.new(genome_params)

    respond_to do |format|
      if @genome.save
        format.html { redirect_to @genome, notice: "Genome was successfully created." }
        format.json { render :show, status: :created, location: @genome }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @genome.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /genomes/1 or /genomes/1.json
  def update
    respond_to do |format|
      if @genome.update(genome_params)
        format.html { redirect_to @genome, notice: "Genome was successfully updated." }
        format.json { render :show, status: :ok, location: @genome }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @genome.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /genomes/1 or /genomes/1.json
  def destroy
    @genome.destroy
    respond_to do |format|
      format.html { redirect_to genomes_url, notice: "Genome was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_genome
      @genome = Genome.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def genome_params
      params.require(:genome).permit(:database, :accession, :type, :gc_content, :completeness, :contamination, :seq_depth, :most_complete_16s, :number_of_16s, :most_complete_23s, :number_of_23s, :number_of_trnas, :updated_by, :auto_check)
    end
end
