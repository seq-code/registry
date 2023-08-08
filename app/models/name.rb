class Name < ApplicationRecord
  has_many(:publication_names, dependent: :destroy)
  has_many(:publications, through: :publication_names)
  has_many(:name_correspondences, dependent: :destroy)
  has_many(
    :children, -> { order(:name) },
    class_name: 'Name', foreign_key: 'parent_id', dependent: :nullify
  )
  has_many(
    :synonyms, class_name: 'Name', foreign_key: 'correct_name_id',
    dependent: :nullify
  )
  alias :correspondences :name_correspondences
  has_many(:checks, dependent: :destroy)
  has_many(:check_users, -> { distinct }, through: :checks, source: :user)
  has_many(:placements, dependent: :destroy)
  has_many(
    :child_placements, class_name: 'Name', foreign_key: 'parent_id',
    dependent: :destroy
  )

  belongs_to(
    :proposed_by, optional: true,
    class_name: 'Publication', foreign_key: 'proposed_by'
  )
  belongs_to(
    :corrigendum_by, optional: true,
    class_name: 'Publication', foreign_key: 'corrigendum_by'
  )
  belongs_to(
    :assigned_by, optional: true,
    class_name: 'Publication', foreign_key: 'assigned_by'
  )
  belongs_to(:parent, optional: true, class_name: 'Name')
  belongs_to(:correct_name, optional: true, class_name: 'Name')
  belongs_to(
    :created_by, optional: true,
    class_name: 'User', foreign_key: 'created_by'
  )
  belongs_to(
    :submitted_by, optional: true,
    class_name: 'User', foreign_key: 'submitted_by'
  )
  belongs_to(
    :endorsed_by, optional: true,
    class_name: 'User', foreign_key: 'endorsed_by'
  )
  belongs_to(
    :validated_by, optional: true,
    class_name: 'User', foreign_key: 'validated_by'
  )
  belongs_to(
    :nomenclature_reviewer, optional: true,
    class_name: 'User', foreign_key: 'nomenclature_reviewer'
  )
  belongs_to(:register, optional: true)
  belongs_to(:tutorial, optional: true)

  before_save(:standardize_etymology)
  before_save(:prevent_self_parent)
  before_save(:monitor_name_changes)

  has_rich_text(:description)
  has_rich_text(:notes)
  has_rich_text(:etymology_text)
  has_rich_text(:incertae_sedis_text) # deprecated, but values still in DB

  validates(:name, presence: true, uniqueness: true)
  validates(
    :syllabication,
    format: {
      with: /\A[A-Z\.'-]*\z/i,
      message: 'Only letters, dashes, dots, and apostrophe are allowed'
    }
  )
  validates(
    :incertae_sedis, absence: {
      if: :parent,
      message: 'cannot be declared if the parent taxon is set'
    }
  )

  include Name::QualityChecks
  include Name::Etymology
  include Name::Citations
  include Name::ExternalResources
  include Name::Inferences

  attr_accessor :only_display

  # ============ --- CLASS --- ============

  class << self

    # ============ --- CLASS > QUERYING --- ============

    def find_variants(name)
      name = name.gsub(/^Candidatus /, '')
      vars = [name, "Candidatus #{name}"]
      Name.where(name: vars)
          .or(Name.where(corrigendum_from: vars))
    end

    def find_by_variants(name)
      variants = find_variants(name)
      return variants.first if variants.count <= 1

      if name =~ /^Candidatus /
        ca = variants.find(&:candidatus?)
        return ca if ca
      else
        non_ca = variants.find { |variant| !variant.candidatus? }
        return non_ca if non_ca
      end

      variants.first
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

    def type_material_hash
      {
        name: { name: 'Name', sp: false },
        nuccore: { name: 'INSDC Nucleotide', sp: true },
        assembly: { name: 'NCBI Assembly', sp: true },
        strain: { name: 'Strain', sp: true },
        other: { name: 'Other', sp: true }
      }
    end

    def type_material_name(type)
      type_material_hash[type.to_sym]&.[](:name)
    end
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

  def abbr_name(name = nil, assume_valid = false)
    name ||= self.name
    if candidatus?
      name.gsub(/^Candidatus /, '<i>Ca.</i> ').html_safe
    elsif (assume_valid || validated?) && name =~ /(.+) subsp\. (.+)/
      "<i>#{$1}</i> subsp. <i>#{$2}</i>".html_safe
    elsif (assume_valid || validated?) || inferred_rank == 'domain'
      "<i>#{name}</i>".html_safe +
        if rank == 'species' && parent&.type_accession&.==(id.to_s)
          " <sup>T#{'s' unless icnp?}</sup>".html_safe
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
        if rank == 'species' && parent&.type_accession&.==(id.to_s)
          " (T#{'s' unless icnp?})"
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
        if rank == 'species' && parent&.type_accession&.==(id.to_s)
          "<sup>T#{'s' unless icnp?}</sup>".html_safe
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
    y += " <i>corrig.</i>".html_safe if corrigendum_by
    if authority || proposed_by
      y += " #{sanitize(authority || proposed_by.short_citation)}"
    end
    if priority_date && priority_date.year != proposed_by&.journal_date&.year
      y += " (valid #{priority_date.year})"
    end
    if emended_by.any?
      cit = emended_by.map(&:short_citation).join('; ')
      y += " <i>emend.</i> #{cit}".html_safe
    end
    y.html_safe
  end

  def formal_txt
    sanitize(formal_html.gsub(/&#822[01];/, "'"))
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
      proposed_by, corrigendum_by, assigned_by, emended_by.to_a
    ].flatten.compact.uniq
  end

  # ============ --- STATUS --- ============

  def status_hash
    self.class.status_hash[status]
  end

  def status_name
    status_hash[:name]
  end

  def status_help
    status_hash[:help].gsub(/\n/, ' ')
  end

  def status_symbol
    status_hash[:symbol]
  end

  def validated?
    status_hash[:valid]
  end

  def public?
    status_hash[:public]
  end

  def after_claim?
    status >= 5
  end

  def after_register?
    register.present? || after_submission?
  end

  def after_submission?
    status >= 10
  end

  def after_endorsement?
    status >= 12
  end

  def after_notification?
    validated? || register.try(:notified?)
  end

  def after_validation?
    valid?
  end

  def after_register_publication?
    register.try(:published?)
  end

  Name.status_hash.each do |k, v|
    define_method("#{v[:symbol]}?") do
      status == k
    end
  end

  # ============ --- OUTLINKS --- ============

  def ncbi_search_url
    q = "%22#{name}%22"
    unless corrigendum_from.nil? || corrigendum_from.empty?
      q += " OR %22#{corrigendum_from}%22"
    end
    "https://www.ncbi.nlm.nih.gov/nuccore/?term=#{q.gsub(' ', '%20')}"
  end

  def links?
    ncbi_taxonomy? || gtdb_genome? || !gbif_homonyms(false, true).empty? ||
      lpsn_url?
  end

  def gtdb_genome?
    type? && type_material == 'assembly'
  end

  def gtdb_genome_url
    return unless gtdb_genome?

    'https://gtdb.ecogenomic.org/genome?gid=%s' % type_accession
  end

  def ncbi_taxonomy_url
    return unless ncbi_taxonomy?

    'https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=%i' % ncbi_taxonomy
  end

  def ncbi_genomes_url
    return unless ncbi_taxonomy?

    'https://www.ncbi.nlm.nih.gov/datasets/genomes/?txid=%i' % ncbi_taxonomy
  end

  def seqcode_url(protocol = true)
    "#{'https://' if protocol}seqco.de/i:#{id}"
  end

  # ============ --- USERS --- ============

  def proposed_by?(publication)
    publication == proposed_by
  end

  def corrigendum_by?(publication)
    publication == corrigendum_by
  end

  def assigned_by?(publication)
    publication == assigned_by
  end

  def emended_by
    publication_names.where(emends: true).map(&:publication)
  end

  def emended_by?(publication)
    emended_by.include? publication
  end

  def user?(user)
    created_by == user
  end

  def can_see?(user)
    return true if public?

    (!user.nil?) && (user.curator? || user?(user))
  end

  def can_see_status?(user)
    can_edit?(user) || can_claim?(user)
  end

  def can_edit?(user)
    return false if only_display
    return false if user.nil?
    return false if validated?
    return true if user.curator?
    return true if draft? && user?(user)
    false
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

  def claim(user)
    raise('User cannot claim name') unless can_claim?(user)
    par = { created_by: user, created_at: Time.now }
    par[:status] = 5 if auto?
    return false unless update(par)

    # Email notification
    AdminMailer.with(
      user: user,
      name: self,
      action: 'claim'
    ).name_status_email.deliver_later

    true
  end

  def can_unclaim?(user)
    curator_or_owner = user.try(:curator?) || self.user?(user)
    curator_or_owner && draft?
  end

  def unclaim(user)
    raise('User cannot unclaim name') unless can_unclaim?(user)
    return false unless update(status: 0)

    # Email notification
    AdminMailer.with(
      user: created_by,
      name: self,
      action: 'unclaim'
    ).name_status_email.deliver_later

    true
  end

  def correspondence_by?(user)
    return false unless user

    correspondences.any? { |msg| msg.user == user }
  end

  def reviewer_ids
    [validated_by, endorsed_by, nomenclature_reviewer].compact.uniq
  end

  def reviewers
    @reviewers ||= User.where(id: reviewer_ids)
  end

  def curators
    @curators ||= (check_users + reviewers).uniq
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

  def type?
    return false unless type_material? && type_accession?

    # TODO
    # This uggly bit is to account for type names that have been
    # eliminated after setting them as type. This causes a mostly
    # unnecessary DB query, so a more efficient solution would be
    # to trigger unlinking on name destruction
    if type_material == 'name' && type_name(false).nil?
      # TODO
      # Set but don't save for now, until this is properly addressed
      self.type_material = nil
      self.type_accession = nil
      false
    else
      true
    end
  end

  def type_is_name?
    type? && type_material == 'name'
  end

  def type_is_genome?
    type? && %w[assembly nuccore].include?(type_material)
  end

  def type_is_strain?
    type? && type_material == 'strain'
  end

  def type_link
    @type_link ||=
      if type_is_genome?
        type_genome.link
      end
  end

  def type_name(check_material = true)
    if !check_material || type_is_name?
      @type_name ||= self.class.where(id: type_accession).first
    end
  end

  attr_writer :type_name

  def type_genome
    if type_is_genome?
      @type_genome ||= Genome.find_or_create(type_material, type_accession)
    end
  end

  def expected_type_rank
    return nil if !rank? || %w[species subspecies domain].include?(rank)
    return 'species' if rank == 'genus'
    'genus'
  end

  def type_material_name
    self.class.type_material_name(type_material) if type?
  end

  def type_accession_text
    type_accession.gsub(/,(?!\s)/, ', ')
  end

  def type_text
    @type_text ||= "#{type_material_name}: #{type_accession_text}" if type?
  end

  def possible_type_materials
    self.class.type_material_hash.select do |_, v|
      v[:sp] == (%w[species subspecies].include?(inferred_rank))
    end
  end

  def genus
    lineage_find(:genus)
  end

  def lineage_find(rank)
    lineage.find { |par| par.rank == rank.to_s }
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
      !children.empty? || taxonomic_status?
  end

  def alt_placements
    @alt_placements ||= placements.where(preferred: false)
  end

  def alt_child_placements
    @alt_child_placements ||= child_placements.where(preferred: false)
  end

  def placement
    @placement ||= placements.where(preferred: true).first
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
      self.created_at = Time.now
    end
    save
  end

  def notified?
    register.try(:notified?)
  end

  def priority_date
    @priority_date ||= self[:priority_date]
    if !@priority_date && seqcode?
      if above_rank?(:family)
        @priority_date = type_name.try(:priority_date)
      else
        @priority_date = register.try(:priority_date)
      end
      update_column(:priority_date, @priority_date)
    end
    @priority_date
  end

  # ============ --- INTERNAL CHECKS --- ============

  ##
  # Return the manual check of type +type+ if set (or nil)
  def check(type)
    # Using +find+ instead of +where().first+ to avoid N+1 queries
    checks.find { |check| check.kind == type.to_s }
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
end
