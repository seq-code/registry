class TaggingService
  class Error < StandardError
  end

  # Returns Array of { 'slug' => String, 'confidence' => one of
  # Tag::CONFIDENCE_LEVELS }, expanded with implied tags (which also carry
  # 'implied_by' => [slugs]); see Tag.expand. Proposals based only on one of
  # their tag's excluded bases are dropped before expansion, so they don't
  # imply other tags either. Gender and classical tags are then decided from
  # the name's own etymology whenever it settles them; see assign_gender and
  # assign_classical
  # Raises TaggingService::Error on unrecoverable failure
  def self.propose(name)
    proposals = drop_excluded_bases(backend.new.propose(name))
    Tag.expand(assign_classical(name, assign_gender(name, proposals)))
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
  # +name+ itself, proposed at high confidence. Otherwise (no gender or
  # several genders declared, as in "masc. / fem. adj.", where the genus
  # decides), the model's gender proposals are kept but capped at medium
  # confidence (carrying 'capped' => true), and reduced to one (see
  # single_gender). Ranks without grammatical gender get no gender tags at
  # all
  def self.assign_gender(name, proposals)
    others = proposals.reject { |p| Tag::GENDER_SLUGS.include?(p['slug']) }
    return others unless Helpers::GENDER_RANKS.include?(name.rank)

    declared = declared_genders(name)
    if declared.size == 1
      return others +
             declared_proposal(declared.first, 'declared in etymology')
    end

    capped = proposals.map do |proposal|
      next proposal unless Tag::GENDER_SLUGS.include?(proposal['slug']) &&
                           proposal['confidence'] == 'high'

      proposal.merge('confidence' => 'medium', 'capped' => true)
    end
    single_gender(check_gender_basis(name, capped))
  end

  # Gender markers ending the basis of the gender of a genitive noun (e.g.
  # "sedimen, -inis, n."), mapped to their tags
  GENDER_MARKERS = {
    'm' => 'masculine', 'masc' => 'masculine',
    'f' => 'feminine', 'fem' => 'feminine',
    'n' => 'neuter', 'neut' => 'neuter'
  }.freeze

  # Make the gender proposals consistent with their basis. A basis ending
  # with a gender marker (e.g. "sedimen, -inis, n.") decides the gender, or
  # gives gender-uncertain at low confidence if it has several markers (e.g.
  # "m./f."), unless the epithet is adjectival or participial: those take
  # the gender of the genus, not of a root in the basis (e.g. ruminiciens,
  # "rumen, -inis, n."). A basis that is the genus name means genus
  # agreement, so the proposal is dropped if the epithet is a genitive
  # noun, to which genus agreement never applies
  def self.check_gender_basis(name, proposals)
    genitive = epithet_grammar?(name, /gen(\.|itive)/)
    adjectival = epithet_grammar?(name, /(adj|part)(\.|ective|iciple)/)
    candidatus = /\ACandidatus /
    genus = genus_name(name).to_s.sub(candidatus, '')
    proposals.filter_map do |proposal|
      next proposal unless Tag::GENDER_SLUGS.include?(proposal['slug'])

      basis = proposal['basis'].to_s.strip
      next if genitive && basis.sub(candidatus, '').casecmp?(genus)

      marked = adjectival ? [] : marked_genders(basis)
      case marked.size
      when 0 then proposal
      when 1 then proposal.merge('slug' => marked.first)
      else
        proposal.merge('slug' => 'gender-uncertain', 'confidence' => 'low')
      end
    end
  end

  # Gender tags marked at the end of +basis+, after a comma (e.g. ", f." or
  # ", m./f."), or none
  def self.marked_genders(basis)
    marker = /(?:masc|fem|neut|m|f|n)\./i
    markers = basis[%r{,\s*(#{marker}(?:\s*(?:/|or|and)\s*#{marker})*)\s*\z}i, 1]
    return [] unless markers

    markers.scan(/(masc|fem|neut|m|f|n)\./i).flatten
           .map { |m| GENDER_MARKERS[m.downcase] }.uniq
  end

  # Whether the grammar of +name+ (a species or subspecies) has a term
  # matching +regex+, treating errors (and missing grammar) as false
  def self.epithet_grammar?(name, regex)
    return false unless %w[species subspecies].include?(name.rank)

    name.grammar_has?(regex) ? true : false
  rescue StandardError
    false
  end

  # Name of the genus of +name+, from its lineage or the name itself
  def self.genus_name(name)
    name.genus&.name || name.name.sub(/\ACandidatus /, '').split.first
  end

  # Keep only the gender proposal of highest confidence, as gender tags are
  # mutually exclusive. If several genders tie at that confidence, keep the
  # model's gender-uncertain proposal among them or, failing that, propose
  # gender-uncertain at low confidence, as the tie means the model is unsure
  # (or no gender, if that tag doesn't exist)
  def self.single_gender(proposals)
    genders, others =
      proposals.partition { |p| Tag::GENDER_SLUGS.include?(p['slug']) }
    return proposals if genders.map { |p| p['slug'] }.uniq.size < 2

    rank = ->(p) { Tag::CONFIDENCE_LEVELS.index(p['confidence']).to_i }
    top = genders.map(&rank).max
    tied = genders.select { |p| rank[p] == top }
    slugs = tied.map { |p| p['slug'] }.uniq
    return others + [tied.first] if slugs.size == 1

    uncertain = tied.find { |p| p['slug'] == 'gender-uncertain' }
    uncertain ||= {
      'slug' => 'gender-uncertain', 'confidence' => 'low',
      'basis' => "tie between #{slugs.join(' and ')}"
    }
    return others unless Tag.exists?(slug: 'gender-uncertain')

    others + [uncertain]
  end

  # Gender tag slugs declared in the grammar of +name+
  def self.declared_genders(name)
    GENDER_PREDICATES.select do |_slug, predicate|
      declares_gender?(name, predicate)
    end.keys
  end

  # Replace the classical proposals with one decided from the etymology if
  # it is a single Latin word identical to the name or epithet (see
  # classical_component and classical_confidence). Otherwise, the model's
  # proposals are kept
  def self.assign_classical(name, proposals)
    component = classical_component(name) or return proposals

    word = name.etymology(component, :particle)
    proposals.reject { |p| p['slug'] == 'classical' } +
      declared_proposal(
        'classical', "L. #{word}", classical_confidence(name, component)
      )
  end

  # The only component of the structured etymology of +name+, if its
  # language is "L." (not "N.L.") and its word is identical to the name or
  # epithet, ignoring case. Only genus, species, and subspecies names are
  # considered, as higher ranks carry rank suffixes. Greek words are left to
  # the model, as transliteration changes their form, and free-text
  # etymologies are not parsed
  def self.classical_component(name)
    return if name.etymology_text? ||
              !Helpers::GENDER_RANKS.include?(name.rank)

    components = Name.etymology_particles.select do |component|
      Name.etymology_fields.any? do |field|
        next if component == :xx && field == :particle # Always the epithet

        name.etymology(component, field).present?
      end
    end
    return unless components.size == 1 &&
                  name.etymology(components.first, :lang) == 'L.'

    word = name.etymology(components.first, :particle)
    components.first if word.present? && word.casecmp?(name.last_epithet)
  end

  # High confidence if the classical +component+ of +name+ has a grammar
  # field and its word contains no generic compound element (see
  # Tag::GENERIC_BASES and Tag::LIVING_BASES), medium otherwise: the label
  # "L." is sometimes given to compounds, but genuine Latin words can also
  # contain those elements (e.g. agricola)
  def self.classical_confidence(name, component)
    word = name.etymology(component, :particle).downcase
    generic = (Tag::GENERIC_BASES + Tag::LIVING_BASES).any? do |base|
      word.include?(base)
    end
    name.etymology(component, :grammar).present? && !generic ? 'high' : 'medium'
  end

  # Whether +predicate+ holds for +name+, treating errors as false
  def self.declares_gender?(name, predicate)
    name.public_send(predicate) ? true : false
  rescue StandardError
    false
  end

  # A proposal of the tag +slug+ decided from the etymology, with +basis+
  # and +confidence+, or none if the tag doesn't exist
  def self.declared_proposal(slug, basis, confidence = 'high')
    return [] unless Tag.exists?(slug: slug)

    [{ 'slug' => slug, 'confidence' => confidence, 'basis' => basis }]
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

    # Gender of the genus of +name+ (a species or subspecies) as [slug,
    # source]: its accepted gender tag or, failing that, the single gender
    # declared in its etymology. Returns nil if unknown
    def genus_gender(name)
      genus = name.genus
      return if genus.nil? || genus == name

      accepted =
        genus.name_tags.joins(:tag)
             .where(status_int: NameTag.status.index(:accepted))
             .where(tags: { slug: Tag::GENDER_SLUGS }).pluck('tags.slug')
      if accepted.size == 1
        return [accepted.first, "accepted tag of #{genus.name}"]
      end

      declared = TaggingService.declared_genders(genus)
      return unless declared.size == 1

      [declared.first, "declared in the etymology of #{genus.name}"]
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

