# frozen_string_literal: true

# Controller for editing actions on names.
class Names::EditingController < Names::BaseController
  # GET /names/1/edit
  def edit
  end

  # GET /names/1/edit_description
  def edit_description
  end

  # GET /names/1/edit_notes
  def edit_notes
  end

  # GET /names/1/edit_rank
  def edit_rank
  end

  # GET /names/1/edit_links
  def edit_links
  end

  # GET /names/1/edit_type
  def edit_type
    unless @name.rank?
      flash[:alert] = 'You must define the rank before the type material'
      redirect_to(@name)
    end
  end

  # GET /names/1/edit_redirect
  def edit_redirect
  end

  # GET /names/1/autofill_etymology
  def autofill_etymology
    @name.autofill_etymology
    render :edit_etymology
  end

  # GET /names/1/edit_etymology
  def edit_etymology
  end

  # GET /names/1/edit_parent
  def edit_parent
    if @name.placement
      redirect_to(edit_placement_path(@name.placement))
    else
      redirect_to(new_placement_path(@name))
    end
  end
end
