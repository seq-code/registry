# frozen_string_literal: true

# A concern to handle filtering for controllers.
# Usage: Include this concern in your controller and call `apply_filters` on your query.
module Filterable
  extend ActiveSupport::Concern

  # Applies filters to a query based on the given filter parameters.
  # @param query [ActiveRecord::Relation] The query to filter.
  # @param filters [Hash] A hash of filter parameters (e.g., { rank: 'genus', status: 15 }).
  # @return [ActiveRecord::Relation] The filtered query.
  def apply_filters(query, filters)
    filters.each do |key, value|
      next if value.nil?
      query = query.where(key => value)
    end
    query
  end

  # Applies sorting to a query based on the given sort parameters.
  # @param query [ActiveRecord::Relation] The query to sort.
  # @param sort_by [String, nil] The field to sort by (defaults to params[:sort]).
  # @param sort_direction [String, nil] The direction to sort ('asc' or 'desc').
  # @return [ActiveRecord::Relation] The sorted query.
  def apply_sort(query, sort_by: nil, sort_direction: nil)
    sort_by ||= params[:sort]
    sort_direction ||= params[:direction] || 'asc'

    return query unless sort_by.present?

    # Handle special sorting cases (e.g., 'citations' for Name model)
    case sort_by.to_s.downcase
    when 'citations'
      query.left_joins(:publication_names).group(:id).order("COUNT(publication_names.id) #{sort_direction.upcase}")
    when 'date'
      # Use validated_at if available, otherwise fall back to created_at
      if query.model.column_names.include?('validated_at')
        query.order("validated_at #{sort_direction.upcase}")
      else
        query.order("created_at #{sort_direction.upcase}")
      end
    else
      # Default sorting by the given field
      query.order("#{sort_by} #{sort_direction.upcase}")
    end
  end
end
