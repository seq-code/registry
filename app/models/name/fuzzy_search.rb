module Name::FuzzySearch
  extend ActiveSupport::Concern

  class_methods do
    # Performs a fuzzy search for names similar to the given query.
    # @param query [String] The search query.
    # @param method [Symbol] The search method (:similarity or :levenshtein).
    # @param threshold [Float, Integer] The threshold for matching.
    # @param limit [Integer] The maximum number of results to return.
    # @param selection [Symbol, ActiveRecord::Relation] The selection of names to search.
    #   Can be :all_valid, :all_public, :valid_genera, :public_genera, or a custom query.
    # @return [ActiveRecord::Relation] The matching names.
    def fuzzy_search(
      query,
      method: :similarity,
      threshold: nil,
      limit: 10,
      selection: :all_valid
    )
      return unless ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'

      selection = resolve_selection(selection)

      case method.to_sym
      when :similarity
        fuzzy_similarity_search(selection, query, threshold || 0.7, limit)
      when :levenshtein
        fuzzy_levenshtein_search(selection, query, threshold || 2, limit)
      else
        raise ArgumentError, "Unsupported fuzzy match method: #{method}"
      end
    end

    private

    def resolve_selection(selection)
      case selection
      when :all_valid
        Name.all_valid
      when :all_public
        Name.all_public
      when :valid_genera
        Name.all_valid.where(rank: :genus)
      when :public_genera
        Name.all_public.where(rank: :genus)
      when ActiveRecord::Relation
        selection
      else
        raise ArgumentError, "Unsupported selection: #{selection}"
      end
    end

    def fuzzy_similarity_search(selection, query, threshold, limit)
      selection
        .select(
          sanitize_sql_array([
            'id, name, similarity(name, ?) AS score',
            query
          ])
        )
        .where('similarity(name, ?) > ?', query, threshold)
        .order('score DESC')
        .limit(limit)
    end

    def fuzzy_levenshtein_search(selection, query, threshold, limit)
      selection
        .select(
          sanitize_sql_array([
            'id, name, levenshtein(name, ?) AS score',
            query
          ])
        )
        .where('levenshtein(name, ?) <= ?', query, threshold)
        .order('score ASC')
        .limit(limit)
    end
  end
end
