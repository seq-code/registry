class TagsController < ApplicationController
  before_action(:set_tag, only: %i[ show edit update destroy ])
  before_action(
    :authenticate_curator!, only: %i[ new create edit update destroy ]
  )

  # GET /tags or /tags.json
  def index
    @crumbs = ['Tags']
    @tags = Tag.all
    @umbrella_tags, @standalone_tags =
      Tag.top_level.with_rich_text_description
         .includes(children: :rich_text_description)
         .order(:name).partition(&:umbrella?)
    @name_counts = visible_names(NameTag.where(status_int: 1).joins(:name))
                     .group(:tag_id).count
  end

  # GET /tags/1 or /tags/1.json
  def show
    @crumbs = [['Tags', tags_url]]
    @crumbs << [@tag.parent.name, @tag.parent] if @tag.parent
    @crumbs << @tag.name
    @accepted_names = visible_names(@tag.accepted_names)
                        .order(:name).paginate(page: params[:page])
    @proposed_names = @tag.name_tags.where(status_int: 0)
                          .includes(:name).order('names.name')
    @rejected_names = @tag.name_tags.where(status_int: 2)
                          .includes(:name).order('names.name')
    @child_tags = @tag.children.order(:name)
  end

  # GET /tags/new
  def new
    @crumbs = [['Tags', tags_url], 'New']
    @tag = Tag.new
  end

  # GET /tags/1/edit
  def edit
    @crumbs = [['Tags', tags_url], [@tag.name, @tag], 'Edit']
  end

  # POST /tags or /tags.json
  def create
    @tag = Tag.new(tag_params)

    respond_to do |format|
      if @tag.save
        format.html { redirect_to tag_url(@tag), notice: "Tag was successfully created." }
        format.json { render :show, status: :created, location: @tag }
      else
        format.html do
          @crumbs = [['Tags', tags_url], 'New']
          render :new, status: :unprocessable_entity
        end
        format.json { render json: @tag.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tags/1 or /tags/1.json
  def update
    respond_to do |format|
      if @tag.update(tag_params)
        format.html { redirect_to tag_url(@tag), notice: "Tag was successfully updated." }
        format.json { render :show, status: :ok, location: @tag }
      else
        format.html do
          @crumbs = [
            ['Tags', tags_url], [@tag.name_in_database, tag_url(@tag)], 'Edit'
          ]
          render :edit, status: :unprocessable_entity
        end
        format.json { render json: @tag.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tags/1 or /tags/1.json
  def destroy
    @tag.destroy

    respond_to do |format|
      format.html { redirect_to tags_url, notice: "Tag was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tag
      @tag = Tag.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def tag_params
      params.require(:tag).permit(
        :name, :slug, :color, :parent_id, :description
      )
    end

    # Hide names that are not yet public from non-curators
    def visible_names(scope)
      current_user.try(:curator?) ? scope : scope.merge(Name.all_public)
    end
end
