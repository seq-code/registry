# frozen_string_literal: true

# A concern to handle Name-specific filtering and sorting for controllers.
# Usage: Include this concern in your controller and call `apply_name_filters` on your query.
module NameFilterable
  extend ActiveSupport::Concern

  included do
    # Default filters for Name model
    def name_status_filters
      {
        'public' => Name.public_status,
        'automated' => 0,
        'seqcode' => 15,
        'icnp' => 20,
        'icnafp' => 25,
        'valid' => Name.valid_status
      }
    end

    # Maps status strings to their corresponding integer values.
    # @param status [String] The status string (e.g., 'SeqCode', 'ICNP').
    # @return [Integer, Array<Integer>] The status value(s).
    def map_status_to_value(status)
      status = status.to_s.downcase
      status = 'icnafp' if status == 'icn'
      name_status_filters[status] || status
    end
  end

  # Applies Name-specific filters to a query.
  # @param query [ActiveRecord::Relation] The query to filter.
  # @param filters [Hash] A hash of filter parameters (e.g., { rank: 'genus', status: 'SeqCode' }).
  # @return [ActiveRecord::Relation] The filtered query.
  def apply_name_filters(query, filters)
    filters.each do |key, value|
      next if value.nil?

      case key.to_sym
      when :rank, :redirect, :status
        query = query.where(key => value)
      when :where
        query = query.where(value)
      end
    end
    query
  end

  # Applies Name-specific sorting to a query.
  # @param query [ActiveRecord::Relation] The query to sort.
  # @param sort_by [String, nil] The field to sort by (defaults to params[:sort]).
  # @return [ActiveRecord::Relation] The sorted query.
  def apply_name_sort(query, sort_by: nil)
    sort_by ||= params[:sort] || 'date'

    case sort_by.to_s.downcase
    when 'date'
      # Use validated_at for SeqCode-validated names, otherwise created_at
      if params[:status] == 'SeqCode' || params[:status] == 'seqcode'
        query.order(validated_at: :desc)
      else
        query.order(created_at: :desc)
      end
    when 'citations'
      query.left_joins(:publication_names).group(:id).order('COUNT(publication_names.id) DESC')
    when 'alphabetically'
      query.order(name: :asc)
    else
      query.order(sort_by => :asc)
    end
  end
end
