class Name < ApplicationRecord
  has_many(:pseudonyms, dependent: :destroy)
  has_many(:publication_names, dependent: :destroy)
  has_many(:publications, through: :publication_names)
  has_many(
    :name_correspondences, -> { order(:created_at) }, dependent: :destroy
  )
  has_many(
    :children, -> { order(:name) },
    class_name: 'Name', foreign_key: 'parent_id', dependent: :nullify
  )
  has_many(
    :valid_children, -> { where('names.status >= 15').order(:name) },
    class_name: 'Name', foreign_key: 'parent_id'
  )
  has_many(
    :synonyms, class_name: 'Name', foreign_key: 'correct_name_id',
    dependent: :nullify
  )
  has_many(
    :redirectors, class_name: 'Name', foreign_key: 'redirect_id',
    dependent: :nullify
  )
  alias :correspondences :name_correspondences
  has_many(:checks, dependent: :destroy)
  has_many(:check_users, -> { distinct }, through: :checks, source: :user)
  has_many(:placements, -> { includes(:parent) }, dependent: :destroy)
  has_many(
    :child_placements, -> { includes(:name) },
    class_name: 'Placement', foreign_key: 'parent_id', dependent: :destroy
  )
  has_many(:observe_names, dependent: :destroy)
  has_many(:observers, through: :observe_names, source: :user)
  has_many(
    :typified_names, class_name: 'Name',
    as: :nomenclatural_type, dependent: :nullify
  )

  belongs_to(:nomenclatural_type, polymorphic: true, optional: true)
  belongs_to(
    :proposed_in, optional: true,
    class_name: 'Publication', foreign_key: 'proposed_in_id'
  )
  belongs_to(
    :corrigendum_in, optional: true,
    class_name: 'Publication', foreign_key: 'corrigendum_in_id'
  )
  belongs_to(
    :assigned_in, optional: true,
    class_name: 'Publication', foreign_key: 'assigned_in_id'
  )
  belongs_to(:parent, optional: true, class_name: 'Name')
  belongs_to(:correct_name, optional: true, class_name: 'Name')
  belongs_to(:redirect, optional: true, class_name: 'Name')
  belongs_to(
    :created_by, optional: true,
    class_name: 'User', foreign_key: 'created_by_id'
  )
  belongs_to(
    :submitted_by, optional: true,
    class_name: 'User', foreign_key: 'submitted_by_id'
  )
  belongs_to(
    :endorsed_by, optional: true,
    class_name: 'User', foreign_key: 'endorsed_by_id'
  )
  belongs_to(
    :validated_by, optional: true,
    class_name: 'User', foreign_key: 'validated_by_id'
  )
  belongs_to(
    :nomenclature_review_by, optional: true,
    class_name: 'User', foreign_key: 'nomenclature_review_by_id'
  )
  belongs_to(
    :genomics_review_by, optional: true,
    class_name: 'User', foreign_key: 'genomics_review_by_id'
  )
  belongs_to(:register, optional: true)
  belongs_to(:tutorial, optional: true)

  before_validation(:observe_nomenclatural_type_entry)
  before_validation(:harmonize_register_and_status)
  before_validation(:standardize_etymology)
  before_validation(:prevent_self_parent)
  before_validation(:monitor_name_changes)
  before_save(:reset_name_order)
  after_save(:clear_cached_objects)
  after_save(:ensure_consistent_placement)
  after_save(:observe_genome_strain)

  has_rich_text(:description)
  has_rich_text(:notes)
  has_rich_text(:etymology_text)
  has_rich_text(:incertae_sedis_text) # deprecated, but values still in DB

  validates(:name, presence: true, uniqueness: true)
  validates(
    :syllabication,
    format: {
      with: /\A[A-Z\.'-]*\z/i,
      message: 'can only contain letters, dashes, dots, and apostrophe'
    }
  )
  validates(
    :incertae_sedis, absence: {
      if: :parent,
      message: 'cannot be declared if the parent taxon is set'
    }
  )
  validates(
    :nomenclatural_type_type,
    presence: {
      if: -> { nomenclatural_type_id? || nomenclatural_type_entry.present? }
    }
  )
  validates(
    :nomenclatural_type_id,
    presence: { if: :nomenclatural_type_type? }
  )

  include HasObservers
  include HasExternalResources
  include Name::Status
  include Name::QualityChecks
  include Name::Etymology
  include Name::Citations
  include Name::ExternalResources
  include Name::Inferences
  include Name::Network
  include Name::Wiki

  attr_accessor :only_display
  attr_accessor :nomenclatural_type_entry
  attr_accessor :qc_for_tutorial

  # ============ --- CLASS --- ============

  class << self

    # ============ --- CLASS > QUERYING --- ============

    def find_variants(name)
      name = name.strip.downcase.gsub(/^candidatus /, '')
      vars = [name, "candidatus #{name}"]
      vars += vars.map { |i| i.gsub(/_+/, ' ') }
      Name.where('LOWER(name) IN (?, ?, ?, ?)', *vars)
          .or(Name.where('LOWER(corrigendum_from) IN (?, ?, ?, ?)', *vars))
          .or(Name.where('LOWER(gtdb_accession) IN (?, ?, ?, ?)', *vars))
          .or(Name.where(
            id: Pseudonym.where('LOWER(pseudonym) IN (?, ?, ?, ?)', *vars)
                         .pluck(:name_id)
          ))
    end

    def find_by_variants(name)
      variants = find_variants(name)
      return if variants.empty?

      p_var = nil
      if variants.count > 1
        if name =~ /^Candidatus /
          ca     = variants.find(&:candidatus?)
          p_var  = ca if ca
        else
          non_ca = variants.find { |variant| !variant.candidatus? }
          p_var  = non_ca if non_ca
        end
      end
      p_var ||= variants.first
      p_var.redirect.present? ? p_var.redirect : p_var
    end

    # ============ --- CLASS > ETYMOLOGY --- ============

    def etymology_particles
      %i[p1 p2 p3 p4 p5 xx]
    end

    def etymology_fields
      %i[lang grammar particle description]
    end

    def domains
      %w[Archaea Bacteria Eukarya]
    end

    def ranks
      %w[domain phylum class order family genus species subspecies]
    end

    def rank_suffixes
      { phylum: 'ota', class: 'ia', order: 'ales', family: 'aceae' }
    end

    def rank_variant(rank, opts = {})
      list =
        if opts[:abbr]
            {
              domain: 'dom.',     kingdom: 'regn.',    phylum: 'phy.',
              class:  'classis',  order:   'ord.',     family: 'fam.',
              genus:  'gen.',     species: 'sp.',      subspecies: 'subsp.'
            }
        elsif opts[:latin]
          if opts[:plural]
            {
              domain: 'dominia',  kingdom: 'regna',    phylum: 'phyla',
              class:  'classes',  order:   'ordines',  family: 'familiae',
              genus:  'genera',   species: 'species',  subspecies: 'subspecies'
            }
          else
            {
              domain: 'dominium', kingdom: 'regnum',   phylum: 'phylum',
              class:  'classis',  order:   'ordo',     family: 'familia',
              genus:  'genus',    species: 'species',  subspecies: 'subspecies'
            }
          end
        else
          if opts[:plural]
            {
              domain: 'domains',  kingdom: 'kingdoms', phylum: 'phyla',
              class:  'classes',  order:   'orders',   family: 'family',
              genus:  'genera',   species: 'species',  subspecies: 'subspecies'
            }
          else
            {
              domain: 'domain',   kingdom: 'kingdom',  phylum: 'phylum',
              class:  'class',    order:   'order',    family: 'families',
              genus:  'genus',    species: 'species',  subspecies: 'subspecies'
            }
          end
        end
      return list unless rank.present?
      var = list[rank.to_s.downcase.to_sym]
      opts[:title] ? var.titleize : var
    end

    def rank_regexps
      Hash[rank_suffixes.map { |k, v| [k, /#{v}$/] }]
    end

    def status_hash
      {
        0 => {
          symbol: :auto, name: 'Automated discovery',
          public: true, valid: false,
          help: <<~TXT
            This name was automatically created by the system and has not
            undergone expert review
          TXT
        },
        5 => {
          symbol: :draft, name: 'Draft',
          public: false, valid: false,
          help: <<~TXT
            This name was created by an author or other registered user,
            and has not undergone expert review
          TXT
        },
        10 => {
          symbol: :submit, name: 'Submitted',
          public: false, valid: false,
          help: <<~TXT
            This name has been submitted for review by the author or other
            registered user and cannot be modified until expert review takes
            place
          TXT
        },
        12 => {
          symbol: :endorsement, name: 'Endorsed',
          public: false, valid: false,
          help: <<~TXT
            This name has been endorsed by expert curators or thoroughly
            checked by automated controls but still lacks one or more conditions
            to be valid, typically effective publication
          TXT
        },
        15 => {
          symbol: :seqcode, name: 'Valid (SeqCode)',
          public: true, valid: true,
          help: <<~TXT
            This name has been validly published under the rules of the SeqCode
            and has priority in the scientific record
          TXT
        },
        20 => {
          symbol: :icnp, name: 'Valid (ICNP)',
          public: true, valid: true,
          help: <<~TXT
            This name has been validly published under the rules of the ICNP
            and has priority in the scientific record
          TXT
        },
        25 => {
          symbol: :icn, name: 'Valid (ICNafp)',
          public: true, valid: true,
          help: <<~TXT
            This name has been validly published under the rules of the ICNafp
            and has priority in the scientific record
          TXT
        }
      }
    end

    # ============ --- CLASS > STATUS AND TYPE --- ============

    def public_status
      status_hash.select { |_, v| v[:public] }.keys
    end

    def valid_status
      status_hash.select { |_, v| v[:valid] }.keys
    end

    def nomenclatural_type_type_hash
      {
        name: { name: 'Name', class: 'Name', sp: false },
        nuccore: { name: 'INSDC Nucleotide', class: 'Genome', sp: true },
        assembly: { name: 'NCBI Assembly', class: 'Genome', sp: true },
        strain: { name: 'Strain', class: 'Strain', sp: true },
        other: { name: 'Other', class: 'GenericTypeMaterial', sp: true }
      }
    end

    # ============ --- CLASS > NOMENCLATURE --- ============

    def corrigendum_kinds
      {
        publication: {
          name: 'Publication', source: 'In unregistered publication'
        },
        seqcode: {
          name: 'SeqCode Registry', source: 'In SeqCode Registry'
        },
        other: {
          name: 'Another source', source: 'In an unregistered source'
        }
      }
    end

    def corrigendum_kinds_opt
      corrigendum_kinds.map { |k, v| [v[:name], k] }
    end
  end

  # ============ --- STATUS --- ============

  def status_hash
    self.class.status_hash[status]
  end

  Name.status_hash.each do |k, v|
    define_method("#{v[:symbol]}?") do
      status == k
    end
  end

  def temporary_editable?
    return false unless temporary_editable_at?
    DateTime.now < temporary_editable_at
  end

  # ============ --- NOMENCLATURE --- ============

  def sanitize(str)
    ActionView::Base.full_sanitizer.sanitize(str)
  end

  def candidatus?
    name.match? /^Candidatus /
  end

  def base_name
    name.gsub(/^Candidatus /, '')
  end

  def abbr_base_name
    base_name.gsub(/^([A-Z])\S+ /, '\\1. ')
  end

  ##
  # Determines if if this name is the nomenclatural type of the parent name,
  # which is only possible (under the SeqCode) for genera and species but rank
  # is not evaluated. Use +is_type_species?+ to test for the rank first and
  # avoid unnecessary database queries
  # 
  # TODO - Performance issue
  # This loads the full parent, which causes N+1 issues when simply rendering
  # a list of names
  def is_parent_type?
    return false unless parent.present?
    parent.nomenclatural_type_type == 'Name' &&
      parent.nomenclatural_type_id == id
  end

  def is_type_species?
    rank == 'species' && is_parent_type?
  end

  def abbr_name(name = nil, assume_valid = false)
    name ||= self.name
    if candidatus?
      name.gsub(/^Candidatus /, '<i>Ca.</i> ').html_safe
    elsif (assume_valid || validated?) && name =~ /(.+) subsp\. (.+)/
      "<i>#{$1}</i> subsp. <i>#{$2}</i>".html_safe
    elsif (assume_valid || validated?) || inferred_rank == 'domain'
      "<i>#{name}</i>".html_safe +
        if is_type_species?
          " <sup>T#{'s' unless icnp? || icn?}</sup>".html_safe
        else
          ''
        end
    else
      "&#8220;#{name}&#8221;".html_safe
    end
  end

  def abbr_name_raw(name = nil, assume_valid = false)
    name ||= self.name
    if candidatus?
      name.gsub(/^Candidatus /, 'Ca. ')
    elsif (assume_valid || validated?) && name =~ /(.+) subsp\. (.+)/
      "#{$1} subsp. #{$2}"
    elsif (assume_valid || validated?) || inferred_rank == 'domain'
      "#{name}" +
        if is_type_species?
          " (T#{'s' unless icnp? || icn?})"
        else
          ''
        end
    else
      "\"#{name}\""
    end
  end

  def name_html(name = nil, assume_valid = false)
    name = sanitize(name || self.name)
    if candidatus?
      name.gsub(/^Candidatus /, '<i>Candidatus</i> ').html_safe
    elsif (assume_valid || validated?) && name =~ /(.+) subsp\. (.+)/
      "<i>#{$1}</i> subsp. <i>#{$2}</i>".html_safe
    elsif (assume_valid || validated?) || inferred_rank == 'domain'
      "<i>#{name}</i>".html_safe +
        if is_type_species?
          "<sup>T#{'s' unless icnp? || icn?}</sup>".html_safe
        end
    else
      "&#8220;#{name}&#8221;".html_safe
    end
  end

  def abbr_corr_name
    abbr_name(corrigendum_from)
  end

  def corr_name_html
    name_html(corrigendum_from)
  end

  def formal_html
    y = name_html
    y = "&#8220;#{y}&#8221;" if candidatus?
    y += ' <i>corrig.</i>'.html_safe if corrigendum_from?
    if not_validly_proposed_in.any?
      y += ' (ex'
      y += not_validly_proposed_in
             .map { |i| " #{sanitize(i.short_citation)}" }.join('; ')
      y += ')'
    end
    if authority || proposed_in
      y += " #{sanitize(authority || proposed_in.short_citation)}"
    end
    if priority_date && priority_date.year != proposed_in&.journal_date&.year
      y += " (priority #{priority_date.year})"
    end
    if emended_in.any?
      cit = emended_in.map(&:short_citation).join('; ')
      y += " <i>emend.</i> #{cit}".html_safe
    end
    y.html_safe
  end

  def formal_txt
    sanitize(formal_html.gsub(/&#822[01];/, "'"))
  end

  def page_description
    y  = base_name + ' is a'
    y += ' candidate' if candidatus?
    y += ' ' + rank if rank?
    y += ' name'
    y += ' ' + validly_published_string
    if !validated? && after_submission?
      y += ' under registration in the SeqCode Registry'
    end
    if proposed_in.present?
      y += ', proposed by ' + proposed_in.short_citation
    end
    y += '.'
    if etymology(:xx, :description).present?
      y += ' The name'
      y += ' (%s)' % last_epithet if sp_or_subsp?
      y += ' stands for: ' + etymology(:xx, :description)
      y += '.' unless y =~ /\.$/
    end
    if is_parent_type?
      y += ' %s is the type %s of the %s %s.' % [
        abbr_base_name, inferred_rank, parent.inferred_rank, parent.base_name
      ]
    elsif !sp_or_subsp? && parent.present?
      y += ' %s is classified as part of the %s %s.' % [
        abbr_base_name, parent.inferred_rank, parent.base_name
      ]
    end
    y
  end

  def display(html = true)
    html ? name_html : name
  end

  def rank_suffix
    self.class.rank_suffixes[inferred_rank.to_s.to_sym]
  end

  ##
  # Pull only the last word in the name
  def last_epithet
    name.gsub(/.* /, '')
  end

  ##
  # Is the last word of the name too long? Defined as 25 characters or longer
  def long_word?
    last_epithet.size >= 25
  end

  ##
  # Is the last word likely hard to pronounce? Defined as words with any of:
  # - 4 or more vowels in a row, where ii, ou, and Latin diphthongs (except ui)
  #   count as a single vowel
  # - 4 or more consonants in a row, where the following count as a single
  #   consonant: sch, ch, ph, th, zh, sh, gh, rh, ts, tz, and any consonant
  #   twice
  def hard_to_pronounce?
    word = last_epithet.downcase
    word.gsub!(/(ou|ii|ae|au|ei|eu|oe)/, '_')
    word.gsub!(/(sch|[cptzsgr]h|[ct]r|t[sz])/, '@')
    word.gsub!(/([^aeiouy_])\1/, '@')
    return true if word =~ /[aeiou_]{4}/ || word =~ /[aeiou_]{3}y($|[^aeiou_])/
    return true if word =~ /[^aeiouy_]{4}/
    false
  end

  def publication_names_ordered
    publication_names.left_joins(:publication).order(journal_date: :desc)
  end

  def citations
    return @citations unless (@citations ||= nil).nil?

    @citations ||= [
      proposed_in, not_validly_proposed_in.to_a, corrigendum_in,
      emended_in.to_a, assigned_in
    ].flatten.compact.uniq
  end

  # ============ --- OUTLINKS --- ============

  def ncbi_search_url
    q = "%22#{name}%22"
    q += " OR %22#{corrigendum_from}%22" if corrigendum_from?
    "https://www.ncbi.nlm.nih.gov/nuccore/?term=#{q.gsub(' ', '%20')}"
  end

  def links?
    return true if public? # <- return Wikispecies for all public names

    ncbi_taxonomy? || gtdb_genome? || !gbif_homonyms(false, true).empty? ||
      lpsn_url? || gtdb_accession? || algaebase_url.present?
  end

  def gtdb_genome?
    type_is_genome? && type_genome.database == 'assembly'
  end

  def gtdb_genome_url
    return unless gtdb_genome?

    'https://gtdb.ecogenomic.org/genome?gid=%s' % type_genome.accession
  end

  def gtdb_tree_url
    return unless gtdb_accession?

    'https://gtdb.ecogenomic.org/tree?r=%s' % gtdb_accession
  end

  def algaebase_text
    algaebase_species? ? 'Species %s' % algaebase_species :
      algaebase_taxonomy? ? 'Taxon %s' % algaebase_taxonomy : nil
  end

  def algaebase_url
    d = 'https://www.algaebase.org'
    if algaebase_species?
      return '%s/search/species/detail/?species_id=%s' % [d, algaebase_species]
    end

    if algaebase_taxonomy?
      return '%s/browse/taxonomy/#%s' % [d, algaebase_taxonomy]
    end

    nil
  end

  def ncbi_taxonomy_url
    return unless ncbi_taxonomy?

    'https://www.ncbi.nlm.nih.gov/datasets/taxonomy/%i/' % ncbi_taxonomy
  end

  def ncbi_genomes_url
    return unless ncbi_taxonomy?

    'https://www.ncbi.nlm.nih.gov/datasets/genome/?taxon=%i' % ncbi_taxonomy
  end

  def seqcode_url(protocol = true)
    "#{'https://' if protocol}seqco.de/i:#{id}"
  end

  def uri
    seqcode_url
  end

  # ============ --- PUBLICATIONS --- ============

  def proposed_in?(publication)
    publication.id == proposed_in_id
  end

  def corrigendum_in?(publication)
    publication.id == corrigendum_in_id
  end

  def assigned_in?(publication)
    publication.id == assigned_in_id
  end

  def corrigendum_source
    corrigendum_kind? ?
      self.class.corrigendum_kinds[corrigendum_kind.to_sym][:source] :
      'In an unknown source'
  end

  def emended_in
    publication_names.where(emends: true).map(&:publication)
  end

  def emended_in?(publication)
    emended_in.include? publication
  end

  def not_validly_proposed_in
    publication_names.where(not_valid_proposal: true).map(&:publication)
  end

  def not_validly_proposed_in?(publication)
    not_validly_proposed_in.include? publication
  end

  # ============ --- USERS --- ============

  def can_view?(user, token = nil)
    return true if public?
    return true if token.present? && token == register.try(:reviewer_token)

    (!user.nil?) && (user.curator? || user?(user))
  end

  def can_see_status?(user)
    can_edit?(user) || can_claim?(user)
  end

  def can_edit?(user)
    return false if only_display
    return false if user.nil?
    return true if temporary_editable? && user.try(:curator?)
    return false if validated? # Except if temporary editable, covered above
    return true if user.curator?
    return true if draft? && user?(user)
    false
  end 

  def can_edit_validated?(user)
    return false if only_display
    can_edit?(user) || user.try(:curator?)
  end

  def can_edit_type?(user)
    return false if only_display
    can_edit?(user) || (can_edit_validated?(user) && !type?)
  end

  def can_view_correspondence?(user)
    return false if only_display
    can_edit?(user) || user?(user)
  end

  def can_claim?(user)
    return false unless user.try(:contributor?)
    return true if auto?
    return true if draft? && user?(user)
    !after_endorsement? && created_by.nil?
  end

  def claimed?(user)
    draft? && user?(user)
  end

  def can_unclaim?(user)
    curator_or_owner = user.try(:curator?) || self.user?(user)
    curator_or_owner && draft?
  end

  def correspondence_by?(user)
    return false unless user

    correspondences.any? { |msg| msg.user == user }
  end

  def reviewer_ids
    [
      validated_by_id, endorsed_by_id,
      nomenclature_review_by_id, genomics_review_by_id
    ].compact.uniq
  end

  def reviewers
    @reviewers ||= User.where(id: reviewer_ids)
  end

  def curators
    @curators ||= (check_users + reviewers).uniq - [user]
  end

  %i[
    created_by submitted_by
    validated_by endorsed_by nomenclature_review_by genomics_review_by
  ].each do |role|
    define_method("#{role}?") do |user|
      user && send("#{role}_id").try(:==, user.id)
    end
  end
  alias :user? :created_by?
  def user
    created_by
  end

  def validated_by?(user)
    validated_by == user
  end

  def corresponding_users
    correspondences.map(&:user).uniq
  end

  def associated_users
    (
      [
        created_by, validated_by, submitted_by, endorsed_by,
        nomenclature_review_by, genomics_review_by
      ] + corresponding_users
    ).compact.uniq
  end

  def observing?(user)
    observe_names.where(user: user).present?
  end

  ##
  # Attempts to add an observer while silently ignoring it if the user
  # already observes the name
  def add_observer(user)
    self.observers << user unless observers.include?(user)
    # Note that rescuing should make the "unless" unnecessary, but this
    # prevents breaking large transactions, as in batch uploads
  rescue ActiveRecord::RecordNotUnique
    true
  end

  # ============ --- TAXONOMY --- ============

  def top_rank?
    rank.to_s == self.class.ranks.first
  end

  ##
  # The current name has a taxonomic rank equal or above +rank+
  def above_rank?(rank)
    self.class.ranks.index(inferred_rank) <= self.class.ranks.index(rank.to_s)
  end

  def expected_parent_rank
    idx = self.class.ranks.index(rank.to_s)
    self.class.ranks[idx - 1] if idx && idx > 0
  end

  def lineage
    @lineage ||= nil
    return @lineage unless @lineage.nil?

    @lineage ||= [self]
    while par = @lineage.first.lineage_parent
      if @lineage.include? par
        self.parent = nil
        @lineage = [self]
        break
      end
      @lineage.unshift(par)
    end
    @lineage.pop
    @lineage
  end

  def lineage_parent
    return parent if parent

    if incertae_sedis? && incertae_sedis =~ /Incertae sedis \((.+)\)/
      self.class.find_by_variants($1)
    end
  end

  def type_name_alt_placement
    return unless type_is_name? && rank

    place = type_name.lineage_find(rank)
    place if place != self
  end

  def incertae_sedis_html
    return '' unless incertae_sedis?

    incertae_sedis.gsub(/(incertae sedis)/i, '<i>\\1</i>').html_safe
  end

  def inferred_rank
    @inferred_rank ||=
      if rank?
        rank
      elsif Name.domains.include?(name)
        'domain'
      elsif base_name =~ / .+ /
        'subspecies'
      elsif base_name =~ / /
        'species'
      elsif name =~ Name.rank_regexps[:family]
        'family'
      elsif name =~ Name.rank_regexps[:order]
        'order'
      elsif name =~ Name.rank_regexps[:class]
        if children.first&.inferred_rank&.== 'species'
          'genus'
        else
          'class'
        end
      elsif name =~ Name.rank_regexps[:phylum]
        'phylum'
      else
        'genus'
      end
  end

  def sp_or_subsp?
    %w[species subspecies].include?(inferred_rank)
  end

  def type?
    nomenclatural_type.present?
  end

  def type_is_name?
    type? && nomenclatural_type_type == 'Name' && nomenclatural_type_id != id
  end

  def type_is_genome?
    type? && nomenclatural_type_type == 'Genome'
  end

  def type_is_strain?
    type? && nomenclatural_type_type == 'Strain'
  end

  def type_link
    @type_link ||=
      if type_is_genome?
        type_genome.link
      end
  end

  def type_name
    nomenclatural_type if type_is_name?
  end

  def type_genome
    nomenclatural_type if type_is_genome?
  end

  def type_strain
    nomenclatural_type if type_is_strain?
  end

  ##
  # Attempts to update the accession of the type genome reusing the same genome
  # entry. If passed, it can also update the database. Please use with caution!
  # Note that MiGA objects are not automatically updated
  def update_type_genome(new_accession, new_database = nil)
    par = { accession: new_accession }
    par[:database] = new_database unless new_database.nil?
    type_genome&.update(par)
  end

  ##
  # Returns the expected type of type as the String representation of the
  # expected class
  # 
  # Note that this differs from +expected_type_rank+ in that the current
  # function uses +inferred_rank+ regardless of defined +rank+
  def expected_type_type
    return 'Name' unless sp_or_subsp?

    if icnp? || icn?
      # Treat with care, as both could also support 'GenericTypeMaterial'
      'Strain'
    else
      'Genome'
    end
  end

  ##
  # Returns the expected rank of nomenclatural type if that's a name, or
  # +nil+ otherwise
  #
  # Note that this differs from +expected_type_type+ in that the current
  # function strictly relies on +rank+ and does not try to +infer_rank+
  def expected_type_rank
    return nil if !rank? || %w[species subspecies].include?(rank)
    return 'species' if rank == 'genus'
    'genus'
  end

  def nomenclatural_type_type_name
    nomenclatural_type.try(:type_of_type)
  end

  def type_of_type
    'Name'
  end

  def type_text
    if type_is_name?
      'Name: ' + type_name.display
    else
      nomenclatural_type.try(:display)
    end
  end

  def possible_nomenclatural_type_types
    self.class.nomenclatural_type_type_hash.select do |_, v|
      v[:sp] == sp_or_subsp?
    end
  end

  def genus
    lineage_find(:genus)
  end

  def lineage_find(rank)
    lineage.find { |par| par.rank == rank.to_s }
  end

  def rank_index
    self.class.ranks.index(inferred_rank)
  end

  def rank_above
    self.class.ranks[rank_index - 1]
  end

  def rank_below
    self.class.ranks[rank_index + 1]
  end

  def propose_lineage_name(rank)
    return name if rank.to_s == inferred_rank
    return if above_rank?(rank)

    case rank.to_s
    when 'species'
      name.gsub(/ (subsp\. )?\S+/, '')
    when 'genus'
      base_name.gsub(/ .*/, '')
    else
      base = "#{propose_lineage_name(:genus)}"
      genus_root(base) + Name.rank_suffixes[rank.to_sym]
    end
  end

  def incertae_sedis_explain
    (placement || self).incertae_sedis_text
  end

  def incertae_sedis
    placement ? placement.incertae_sedis : self[:incertae_sedis]
  end

  def incertae_sedis?
    incertae_sedis.present?
  end

  def taxonomic_data?
    description? || notes? || parent || incertae_sedis? ||
      taxonomic_status? || !children.empty? || !alt_child_placements.empty?
  end

  def alt_placements
    @alt_placements ||= placements.where(preferred: false)
  end

  def alt_child_placements
    @alt_child_placements ||= child_placements.where(preferred: false)
  end

  def alt_children
    alt_child_placements.map(&:name)
  end

  def placement
    @placement ||= placements.where(preferred: true).first
  end

  def consistent_placement?
    placement.try(:parent_id) == parent_id
  end

  def ensure_consistent_placement!
    ensure_consistent_placement
  end

  # ============ --- GENOMICS --- ============

  def genome?
    type_is_genome? || genome_id?
  end

  def genome
    return unless genome?

    @genome ||= type_genome || Genome.find(genome_id)
  end

  # ============ --- REGISTER LISTS --- ============

  def add_to_register(register, user)
    self.register = register
    unless created_by
      self.created_by = user
      self.claimed_at = Time.now
    end
    save
  end

  def notified?
    !!register.try(:notified?)
  end

  # Find the earliest publication date of either the effective publication
  # or any non-valid "original" publication
  def earliest_publication_date
    date = proposed_in.try(:journal_date).try(:to_datetime)
    not_validly_proposed_in.each do |nv_pub|
      nv_time = nv_pub.journal_date.try(:to_datetime) or next
      date ||= nv_time
      date = nv_time if nv_time < date
    end
    date
  end

  def priority_date
    @priority_date ||= self[:priority_date]
    if !@priority_date && seqcode?
      if above_rank?(:family)
        @priority_date = type_name.try(:priority_date)
      elsif genus_affected_by_23d_amendment?
        # Whitman amendment to Rule 23d
        @priority_date = earliest_publication_date
      else
        @priority_date = register.try(:priority_date)
      end
      update_column(:priority_date, @priority_date)
    end
    @priority_date
  end

  ##
  # Would this genus be affected by the protection of Rule 23d
  # if validly published? Note that an additional check for the
  # current date might be necessary (i.e., before 2027)
  def genus_would_be_affected_by_23d_amendment?
    (seqcode? || !validated?) &&
      inferred_rank == 'genus' &&
      earliest_publication_date.try(:year).present? &&
      earliest_publication_date.year < 2022
  end

  ##
  # Is this a genus falling under the protection of Rule 23d?
  def genus_affected_by_23d_amendment?
    seqcode? &&
      genus_would_be_affected_by_23d_amendment? &&
      register.try(:priority_date).try(:year).present? &&
      register.priority_date.year < 2027
  end

  ##
  # Is this name affected directly (genus) or indirectly (family and above)
  # by the protection of Rule 23d?
  def affected_by_23d_amendment?
    return true if genus_affected_by_23d_amendment?

    seqcode? &&
      type_is_name? &&
      type_name.genus_affected_by_23d_amendment?
  end

  # ============ --- INTERNAL CHECKS --- ============

  ##
  # Return the relevant embargo date, be it created_at or claimed_at
  def embargo_at
    return claimed_at if claimed_at.present?
    created_at
  end

  ##
  # Calculate when the embargo of this name would expire
  def embargo_until
    embargo_at + 1.year
  end

  ##
  # Evaluate if the embargo time for this name has already expired
  def embargo_expired?
    return(false) if public?
    embargo_at < 1.year.ago
  end

  ##
  # Return the manual check of type +type+ if set (or nil)
  def check(type)
    # Using +find+ instead of +where().first+ to avoid N+1 queries
    checks.find { |check| check.kind == type.to_s }
  end

  def fresh_name_order
    y = ''
    if parent && parent.rank_index < rank_index
      # Use parent name_order if available
      parent.update_name_order
      y = parent.name_order + '~'
    else
      # If no parent, fill-up ranks with '{}' up to the root
      y = (0 .. rank_index - 1).map { |i| '%02i|{}' % i }.join('~') + '~'
    end
    y += '%02i' % rank_index

    # Sort valid names first
    y += validated? ? '@' : '|'

    # Sort by type genus (or name for genera) if available,
    # ortherwise sort by name *after* those with type name
    y += inferred_rank == 'genus' ? wiki_url_name :
         type_is_name? ? type_name.wiki_url_name : "{#{wiki_url_name}}"
  end

  def update_name_order
    no = fresh_name_order
    update_column(:name_order, no) unless name_order == no
  end

  def nomenclatural_type_from_entry
    acc = nomenclatural_type_entry.to_s.strip
    return nil unless acc.present?

    case nomenclatural_type_type.to_s.downcase
    when 'name'
      acc =~ /\A[0-9]+\z/ ?
        Name.where(id: acc).first :
        Name.find_by_variants(acc)
    when 'genome'
      Genome.where(id: acc).first
    when 'strain'
      Strain.find_or_create_by(numbers_string: acc)
    when *Genome.db_names.keys.map(&:to_s)
      Genome.find_or_create(nomenclatural_type_type, acc)
    else
      GenericTypeMaterial.find_or_create_by(text: acc)
    end
  end

  def old_type_definition
    ['name', id]
  end

  private

  def prevent_self_parent
    parent = nil if parent_id == id
  end

  def monitor_name_changes
    return unless name_changed?

    self.itis_json = nil
    self.itis_at = nil
    self.irmng_json = nil
    self.irmng_at = nil
    self.col_json = nil
    self.col_at = nil
    self.gbif_json = nil
    self.gbif_at = nil

    self.name.strip!
    self.name.gsub!(/\s+/, ' ')
  end

  def observe_nomenclatural_type_entry
    return if nomenclatural_type_entry.nil?

    self.nomenclatural_type = nomenclatural_type_from_entry
  end

  def observe_genome_strain
    return unless type_genome.present?

    type_genome.update(
      strain: genome_strain.present? ?
        Strain.find_or_create_by(numbers_string: genome_strain) : nil
    )
  end

  def harmonize_register_and_status
    self.status = 5 if !register && in_curation?
  end

  def ensure_consistent_placement
    if parent_id.present? || incertae_sedis.present?
      pp = placements.where(
        parent_id: parent_id, incertae_sedis: incertae_sedis
      ).first
      if pp.present?
        if pp.preferred?
          true
        else
          placements.update(preferred: false) && pp.update(preferred: true)
        end
      else
        placements.update(preferred: false) &&
          Placement.new(
            name_id: id, parent_id: parent_id, incertae_sedis: incertae_sedis,
            incertae_sedis_text: incertae_sedis_text, preferred: true
          ).save
      end
    else
      # Conservatively preserve as alternative placement
      placements.update(preferred: false)
    end
  end

  def reset_name_order
    self.name_order = fresh_name_order
  end

  def clear_cached_objects
    @citations = nil
    @reviewers = nil
    @curators  = nil
    @lineage   = nil
    @alt_placements = nil
    @alt_child_placements = nil
    @placement = nil
    @genome    = nil
    @priority_date = nil
  end
end
