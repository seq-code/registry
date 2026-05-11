# frozen_string_literal: true

# A concern to handle pagination for controllers.
# Usage: Include this concern in your controller and call `paginate` on your query.
module Paginatable
  extend ActiveSupport::Concern

  included do
    # Default pagination parameters
    def default_per_page
      30
    end
  end

  # Paginates a query with the given parameters.
  # @param query [ActiveRecord::Relation] The query to paginate.
  # @param page [Integer, nil] The page number (defaults to params[:page]).
  # @param per_page [Integer, nil] The number of items per page (defaults to default_per_page).
  # @return [ActiveRecord::Relation] The paginated query.
  def paginate(query, page: nil, per_page: nil)
    page ||= params[:page]
    per_page ||= default_per_page
    query.paginate(page: page, per_page: per_page)
  end
end
