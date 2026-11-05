class TaggingService
  class Error < StandardError
  end

  # Returns Array of { 'slug' => String, 'confidence' => one of
  # Tag::CONFIDENCE_LEVELS }, expanded with implied tags (which also carry
  # 'implied_by' => [slugs]); see Tag.expand. Proposals based only on one of
  # their tag's excluded bases are dropped before expansion, so they don't
  # imply other tags either. Gender tags are then decided from the name's
  # own etymology whenever it declares a gender; see assign_gender
  # Raises TaggingService::Error on unrecoverable failure
  def self.propose(name)
    proposals = drop_excluded_bases(backend.new.propose(name))
    Tag.expand(assign_gender(name, proposals))
  end

  # Gender tag slugs and the Name predicate declaring each gender
  GENDER_PREDICATES = {
    'masculine' => :masculine?,
    'feminine' => :feminine?,
    'neuter' => :neuter?
  }.freeze

  def self.drop_excluded_bases(proposals)
    excluded =
      Tag.where.not(excluded_bases: [nil, ''])
         .to_h { |tag| [tag.slug, tag.excluded_bases_list] }
    proposals.reject do |proposal|
      excluded.fetch(proposal['slug'], [])
              .include?(Tag.normalize_basis(proposal['basis']))
    end
  end

  # Replace the gender proposals with the gender declared in the grammar of
  # +name+ itself: a single declared gender is proposed at high confidence,
  # and several declared genders as gender-uncertain. If none is declared,
  # the model's gender proposals are kept but capped at medium confidence
  # (carrying 'capped' => true). Ranks without grammatical gender get no
  # gender tags at all
  def self.assign_gender(name, proposals)
    others = proposals.reject { |p| Tag::GENDER_SLUGS.include?(p['slug']) }
    return others unless Helpers::GENDER_RANKS.include?(name.rank)

    declared = GENDER_PREDICATES.select do |_slug, predicate|
      declares_gender?(name, predicate)
    end.keys
    case declared.size
    when 0
      proposals.map do |proposal|
        next proposal unless Tag::GENDER_SLUGS.include?(proposal['slug']) &&
                             proposal['confidence'] == 'high'

        proposal.merge('confidence' => 'medium', 'capped' => true)
      end
    when 1
      others + declared_gender(declared.first, 'declared in etymology')
    else
      others + declared_gender(
        'gender-uncertain', 'declared in etymology (multiple genders)'
      )
    end
  end

  # Whether +predicate+ holds for +name+, treating errors as false
  def self.declares_gender?(name, predicate)
    name.public_send(predicate) ? true : false
  rescue StandardError
    false
  end

  # A high-confidence proposal of the gender tag +slug+ with +basis+, or none
  # if the tag doesn't exist
  def self.declared_gender(slug, basis)
    return [] unless Tag.exists?(slug: slug)

    [{ 'slug' => slug, 'confidence' => 'high', 'basis' => basis }]
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

