# frozen_string_literal: true


# Service object to handle fuzzy search for names.
# This encapsulates the logic for finding similar names using
# PostgreSQL's similarity functions.
class FuzzySearchService
  # Performs a fuzzy search for names similar to the given query.
  # @param query [String] The search query.
  # @param method [Symbol] The search method (:similarity or :levenshtein).
  # @param threshold [Float, Integer] The threshold for matching.
  # @param limit [Integer] The maximum number of results to return.
  # @param selection [Symbol, ActiveRecord::Relation] The selection of names to search.
  #   Can be :all_valid, :all_public, :valid_genera, :public_genera, or a custom query.
  # @return [ActiveRecord::Relation] The matching names.
  def self.call(
    query,
    method: :similarity,
    threshold: nil,
    limit: 10,
    selection: :all_valid
  )
    return unless ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'

    selection = resolve_selection(selection)
    clean_query = ActiveRecord::Base.connection.quote(query)

    case method.to_sym
    when :similarity
      perform_similarity_search(selection, clean_query, threshold || 0.7, limit)
    when :levenshtein
      perform_levenshtein_search(selection, clean_query, threshold || 2, limit)
    else
      raise ArgumentError, "Unsupported fuzzy match method: #{method}"
    end
  end

  private_class_method def self.resolve_selection(selection)
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

  private_class_method def self.perform_similarity_search(selection, query, threshold, limit)
    selection
      .select("id, name, similarity(name, #{query}) AS score")
      .where('similarity(name, ?) > ?', query, threshold)
      .order('score DESC')
      .limit(limit)
  end

  private_class_method def self.perform_levenshtein_search(selection, query, threshold, limit)
    selection
      .select("id, name, levenshtein(name, #{query}) AS score")
      .where('levenshtein(name, ?) <= ?', query, threshold)
      .order('score ASC')
      .limit(limit)
  end
end
