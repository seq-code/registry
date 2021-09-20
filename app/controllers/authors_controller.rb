class AuthorsController < ApplicationController
  before_action :set_author, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_contributor!, only: [:new, :edit, :create, :update, :destroy]

  # GET /authors
  # GET /authors.json
  def index
    @sort = params[:sort]
    @authors =
      case @sort
      when 'date'
        Author.order(created_at: :desc)
      when 'publications'
        Author
          .left_joins(:publications).group(:id)
          .order('COUNT(publications.id) DESC')
      else
        @sort = 'alphabetically'
        Author.order(name: :asc)
      end
    @authors = @authors.paginate(page: params[:page], per_page: 100)
    @crumbs = ['Authors']
  end

  # GET /authors/1
  # GET /authors/1.json
  def show
    @publications = @author.publications.paginate(page: params['page'], per_page: 10)
    @crumbs = [['Authors', authors_path], @author.family]
  end

  # GET /authors/new
  def new
    @author = Author.new
  end

  # GET /authors/1/edit
  def edit
  end

  # POST /authors
  # POST /authors.json
  def create
    @author = Author.new(author_params)

    respond_to do |format|
      if @author.save
        format.html { redirect_to @author, notice: 'Author was successfully created.' }
        format.json { render :show, status: :created, location: @author }
      else
        format.html { render :new }
        format.json { render json: @author.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /authors/1
  # PATCH/PUT /authors/1.json
  def update
    respond_to do |format|
      if @author.update(author_params)
        format.html { redirect_to @author, notice: 'Author was successfully updated.' }
        format.json { render :show, status: :ok, location: @author }
      else
        format.html { render :edit }
        format.json { render json: @author.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /authors/1
  # DELETE /authors/1.json
  def destroy
    @author.destroy
    respond_to do |format|
      format.html { redirect_to authors_url, notice: 'Author was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_author
      @author = Author.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def author_params
      params.require(:author).permit(:given, :family)
    end
end
