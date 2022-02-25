class Name < ApplicationRecord
  has_many(:publication_names, dependent: :destroy)
  has_many(:publications, through: :publication_names)
  has_many(:name_correspondences)
  alias :correspondences :name_correspondences
  belongs_to(
    :proposed_by, optional: true,
    class_name: 'Publication', foreign_key: 'proposed_by'
  )
  belongs_to(
    :corrigendum_by, optional: true,
    class_name: 'Publication', foreign_key: 'corrigendum_by'
  )
  belongs_to(:parent, optional: true, class_name: 'Name')
  belongs_to(
    :created_by, optional: true,
    class_name: 'User', foreign_key: 'created_by'
  )
  belongs_to(
    :submitted_by, optional: true,
    class_name: 'User', foreign_key: 'submitted_by'
  )
  belongs_to(
    :approved_by, optional: true,
    class_name: 'User', foreign_key: 'approved_by'
  )
  belongs_to(
    :validated_by, optional: true,
    class_name: 'User', foreign_key: 'validated_by'
  )
  belongs_to(:register, optional: true)

  before_save(:standardize_grammar)
  before_save(:prevent_self_parent)
  before_save(:monitor_name_changes)

  has_rich_text(:description)
  has_rich_text(:notes)
  has_rich_text(:etymology_text)
  has_rich_text(:incertae_sedis_text)

  validates(:name, presence: true, uniqueness: true)
  validates(
    :syllabication,
    format: {
      with: /\A[A-Z\.'-]*\z/i,
      message: 'Only letters, dashes, dots, and apostrophe are allowed'
    }
  )
  validates(:incertae_sedis_text, presence: true, if: :incertae_sedis?)
  validates(
    :incertae_sedis, absence: {
      if: :parent,
      message: 'cannot be declared if the parent taxon is set'
    }
  )

  include Name::QualityChecks
  include Name::Etymology
  include Name::Citations
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
          symbol: :approval, name: 'Approved',
          public: false, valid: false,
          help: <<~TXT
            This name has been approved by expert curators or thoroughly
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

    # ============ --- CLASS > STATUS --- ============

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
        other: { name: 'Other', sp: true }
      }
    end
  end

  # ============ --- NOMENCLATURE --- ============
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
          " <sup>T#{'s' if status != 20}</sup>".html_safe
        end
    else
      "&#8220;#{name}&#8221;".html_safe
    end
  end

  def name_html(name = nil, assume_valid = false)
    name ||= self.name
    if candidatus?
      name.gsub(/^Candidatus /, '<i>Candidatus</i> ').html_safe
    elsif (assume_valid || validated?) && name =~ /(.+) subsp\. (.+)/
      "<i>#{$1}</i> subsp. <i>#{$2}</i>".html_safe
    elsif (assume_valid || validated?) || inferred_rank == 'domain'
      "<i>#{name}</i>".html_safe +
        if rank == 'species' && parent&.type_accession&.==(id.to_s)
          "<sup>T#{'s' if status != 20}</sup>".html_safe
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
    y += " #{proposed_by.short_citation}" if proposed_by
    if priority_date && priority_date.year != proposed_by&.journal_date&.year
      y += " [valid #{priority_date.year}]"
    end
    if emended_by.any?
      y += " <i>emend.</i> #{emended_by.map(&:short_citation).join('; ')}".html_safe
    end
    y.html_safe
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
  #   consonant: sch, ch, ph, th, zh, sh, gh, ts, tz, and any consonant twice
  def hard_to_pronounce?
    word = last_epithet.downcase
    word.gsub!(/(ou|ii|ae|au|ei|eu|oe)/, '_')
    word.gsub!(/(sch|[cptzsg]h|[ct]r|t[sz])/, '@')
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
      proposed_by, corrigendum_by, emended_by.to_a
    ].flatten.compact
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

  def after_submission?
    status >= 10
  end

  def after_approval?
    status >= 12
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
    "https://www.ncbi.nlm.nih.gov/nuccore/?term=#{q}".gsub(' ', '%20')
  end

  def links?
    ncbi_taxonomy?
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
    return true if self.public?

    (!user.nil?) && (user.curator? || user?(user))
  end

  def can_edit?(user)
    return false if only_display
    return false if user.nil?
    return false if status >= 15
    return true if user.curator?
    return true if status == 5 && user?(user)
    false
  end

  def can_claim?(user)
    return false unless user&.contributor?
    return true if status == 0
    !after_approval? && created_by.nil?
  end

  # ============ --- TAXONOMY --- ============

  def top_rank?
    rank.to_s == self.class.ranks.first
  end

  def expected_parent_rank
    idx = self.class.ranks.index(rank.to_s)
    self.class.ranks[idx - 1] if idx && idx > 0
  end

  def lineage
    @lineage ||= nil
    return @lineage unless @lineage.nil?

    @lineage ||= [self]
    while par = @lineage.first.parent
      @lineage.unshift(par)
    end
    @lineage.pop
    @lineage
  end

  def incertae_sedis_html
    return '' unless incertae_sedis?

    incertae_sedis.gsub(/(incertae sedis)/i, '<i>\\1</i>').html_safe
  end

  def children
    @children ||= Name.where(parent: self)
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
    type_material? && type_accession?
  end

  def type_is_name?
    type? && type_material == 'name'
  end

  def type_is_genome?
    type? && %w[assembly nuccore].include?(type_material)
  end

  def type_link
    @type_link ||=
      case type_material
      when 'assembly', 'nuccore'
        "https://www.ncbi.nlm.nih.gov/#{type_material}/#{type_accession}"
      end
  end

  def type_name
    if type_is_name?
      @type_name ||= self.class.where(id: type_accession).first
    end
  end

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
    self.class.type_material_hash[type_material.to_sym][:name] if type?
  end

  def type_text
    @type_text ||= "#{type_material_name}: #{type_accession}" if type?
  end

  def possible_type_materials
    self.class.type_material_hash.select do |_, v|
      v[:sp] == (%w[species subspecies].include?(inferred_rank))
    end
  end

  def genus
    lineage.find { |par| par.rank == 'genus' }
  end

  # ============ --- OTHER TAXONOMIES --- ============

  def external_request(uri)
    require 'uri'
    require 'net/http'

    res = Net::HTTP.get_response(URI(uri))
    res.is_a?(Net::HTTPSuccess) ? (res.body || '{}') : nil
  rescue
    nil
  end

  def external_search(service)
    send("#{service}_search")
  end

  def external_json(service)
    send("#{service}_json")
  end

  def external_at(service)
    send("#{service}_at")
  end

  def external_hash(service)
    @external_hash ||= {}
    @external_hash[service] ||= nil
    return @external_hash[service] unless @external_hash[service].nil?

    if !external_json(service) || external_at(service) < 2.months.ago
      external_search(service)
    end

    if external_json(service)
      @external_hash[service] = JSON.parse(
        external_json(service), symbolize_names: true
      )
    else
      nil
    end
  end

  def itis_search
    base = 'https://www.itis.gov/ITISWebService/jsonservice'
    uri  = "#{base}/searchByScientificNameExact?srchKey=#{base_name}"
    body = external_request(uri)
    update(itis_json: body, itis_at: Time.now) if body
  end

  def itis_hash
    external_hash(:itis)
  end

  def itis_homonyms
    return [] unless itis_hash

    base = 'https://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&'
    names = itis_hash[:scientificNames].compact || []
    names.map do |i|
      "<a href=\"#{base}&search_value=#{i[:tsn]}\" target=_blank>" \
        "<i>#{i[:combinedName]}</i> #{i[:author]} (<i>#{i[:kingdom]}</i>)" \
        "</a>"
    end
  end

  def irmng_search
    base = 'https://www.irmng.org/rest/AphiaRecordsByNames'
    uri  = "#{base}?scientificnames[]=#{base_name}&like=false"
    body = external_request(uri)
    update(irmng_json: body, irmng_at: Time.now) if body
  end

  def irmng_hash
    external_hash(:irmng)
  end

  def irmng_homonyms
    return [] unless irmng_hash && !irmng_hash.empty?

    (irmng_hash.first || []).map do |i|
      "<a href=\"#{i[:url]}\" target=_blank>" \
        "<i>#{i[:scientificname]}</i> #{i[:authority]} (<i>#{i[:kingdom]}</i>)" \
        "</a>"
    end
  end

  def col_search
    base = 'https://api.catalogueoflife.org/name/matching'
    uri  = "#{base}?q=#{base_name}&verbose=true"
    body = external_request(uri)
    update(col_json: body, col_at: Time.now) if body
  end

  def col_hash
    external_hash(:col)
  end

  def col_homonyms
    return [] unless col_hash && col_hash[:type] == 'exact'

    (col_hash[:alternatives] || []).map do |i|
      "#{i[:labelHtml]} " \
        "(<a href=\"https://www.catalogueoflife.org/\" target=_blank>COL</a>)"
    end
  end

  def external_homonyms
    # Try IRMNG, which is the fastest and best formatted option
    return irmng_homonyms unless irmng_homonyms.empty?

    # Next, try ITIS, which is slower but very conveniently formatted
    return itis_homonyms unless itis_homonyms.empty?

    # Finally, try COL, which is the least convenient but most comprehensive
    return col_homonyms unless col_homonyms.empty?

    []
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
    register&.notified?
  end

  def priority_date
    register&.priority_date
  end

  # ============ --- INTERNAL CHECKS --- ============

  private

  def standardize_grammar
    return unless etymology?

    self.class.etymology_particles.each do |i|
      # Standardize language
      l = etymology(i, :lang)
      p = "etymology_#{i}_lang="
      case l.to_s.downcase
      when 'latin'
        self.send(p, 'L.')
      when 'new latin', /neo[ -]?latin/
        self.send(p, 'N.L.')
      when 'greek'
        self.send(p, 'Gr.')
      end

      # Ensure grammar indicators are separated by spaces
      g = etymology(i, :grammar)
      self.send("etymology_#{i}_grammar=", g.gsub(/\.(\S)/, '. \1')) if g
    end

    # Check if the last particle should be the full epithet
    lc = last_component
    return if grammar || language
    return unless last_epithet.downcase == etymology(lc, :particle).downcase

    self.class.etymology_fields.each do |i|
      self.send("etymology_xx_#{i}=", etymology(lc, i)) unless i == :particle
      self.send("etymology_#{lc}_#{i}=", nil)
    end
  end

  def prevent_self_parent
    parent = nil if parent_id == id
  end

  def monitor_name_changes
    if name_changed?
      self.itis_json = nil
      self.itis_at = nil
      self.irmng_json = nil
      self.irmng_at = nil
      self.col_json = nil
      self.col_at = nil
    end
  end
end
