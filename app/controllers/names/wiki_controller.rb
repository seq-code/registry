# frozen_string_literal: true

# Controller for wiki-related actions on names.
class Names::WikiController < Names::BaseController
  # GET /names/1/wiki
  def wiki
    @crumbs = [['Names', names_path], [@name.abbr_name, @name], 'Wiki source']
    @name.check_wikispecies if current_user # Force re-check for logged users
    @name_page = :wiki
  end
end
