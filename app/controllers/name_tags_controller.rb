class NameTagsController < ApplicationController
  before_action(:authenticate_user!, only: %i[create])
  before_action(:authenticate_curator!, only: %i[update destroy pending])
  before_action(:set_name_tag, only: %i[update destroy])

  # GET /name_tags/pending
  def pending
    @crumbs = [['Tags', tags_url], 'Pending tags']
    @names =
      Name.where(id: NameTag.where(status_int: 0).select(:name_id))
          .includes(name_tags: { tag: :rich_text_description }).order(:name)
          .paginate(page: params[:page], per_page: 30)
  end

  # POST /name_tags
  def create
    @name_tag = NameTag.new(name_tag_params)
    name = @name_tag.name

    if name.nil? || !name.can_edit_validated?(current_user)
      flash[:alert] = 'Action not allowed'
      redirect_back(fallback_location: root_path) and return
    end

    if @name_tag.save
      flash[:notice] = "Tag #{@name_tag.status} for #{name.name}"
    else
      flash[:danger] =
        'Tag could not be applied: ' +
        @name_tag.errors.full_messages.to_sentence
    end
    redirect_back(fallback_location: name)
  end

  # PATCH /name_tags/1
  def update
    if @name_tag.update(
         params.require(:name_tag).permit(:status_int, :notes)
       )
      flash[:notice] = "Tag #{@name_tag.status}"
    else
      flash[:danger] = 'Tag could not be updated'
    end
    redirect_back(fallback_location: @name_tag.name)
  end

  # DELETE /name_tags/1
  def destroy
    name = @name_tag.name
    @name_tag.destroy
    flash[:notice] = 'Tag removed'
    redirect_back(fallback_location: name)
  end

  private
    def set_name_tag
      @name_tag = NameTag.find(params[:id])
    end

    # Only allow a list of trusted parameters through. Non-curators can only
    # propose tags under their own username
    def name_tag_params
      par = params
              .require(:name_tag)
              .permit(:name_id, :tag_id, :status_int, :proposed_by, :notes)
      if current_user.curator?
        par[:status_int] = 1 if par[:status_int].blank?
        par[:proposed_by] = current_user.username if par[:proposed_by].blank?
      else
        par[:status_int] = 0
        par[:proposed_by] = current_user.username
      end
      par
    end
end
