class TaggingService
  class Error < StandardError
  end

  # Returns Array of { slug: String, confidence: "high" | "low" }
  # Raises TaggingService::Error on unrecoverable failure
  def self.propose(name)
    backend.new.propose(name)
  end

  def self.backend
    case Rails.configuration.tagging_backend
    when :anthropic ; TaggingService::AnthropicBackend
    when :local     ; TaggingService::LocalBackend
    else
      raise(
        Error,
        "Unknown tagging backend: #{Rails.configuration.tagging_backend}"
      )
    end
  end

  # Shared helpers available to all backends
  module Helpers
    GENDER_RANKS = %w[genus species subspecies].freeze

    # Assemble a compact text representation of the structured etymology
    # particles, falling back gracefully if fields are absent
    def etymology_text(name)
      if name.etymology?
        name.full_etymology(false).presence ||
          structured_etymology(name)
      else
        nil
      end
    end

    def structured_etymology(name)
      Name.etymology_particles.filter_map do |component|
        name.partial_etymology(component, false)
      end.join('; ').presence
    end

    def gender_applicable?(name)
      GENDER_RANKS.include?(name.rank)
    end

    # Validate returned slugs against known tags, return only valid ones
    def valid_slugs
      @valid_slugs ||= Tag.pluck(:slug).to_set
    end

    def filter_proposals(proposals)
      proposals.select { |p| valid_slugs.include?(p['slug']) }
    end
  end
end

