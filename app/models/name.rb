class Name < ApplicationRecord
  has_many(:publication_names, dependent: :destroy)
  has_many(:publications, through: :publication_names)
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
    :validated_by, optional: true,
    class_name: 'User', foreign_key: 'validated_by'
  )

  before_save(:standardize_grammar)
  before_save(:prevent_self_parent)

  has_rich_text(:description)
  has_rich_text(:notes)
  has_rich_text(:etymology_text)

  validates(:name, presence: true, uniqueness: true)
  validates(
    :syllabication,
    format: {
      with: /\A[A-Z\.'-]*\z/i,
      message: 'Only letters, dashes, dots, and apostrophe are allowed'
    }
  )

  include Name::QualityChecks
  include Name::Etymology

  # ============ --- CLASS --- ============

  class << self

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

  def abbr_name(name = nil)
    name ||= self.name
    if candidatus?
      name.gsub(/^Candidatus /, '<i>Ca.</i> ').html_safe
    elsif validated? && name =~ /(.+) subsp\. (.+)/
      "<i>#{$1}</i> subsp. <i>#{$2}</i>".html_safe
    elsif validated? || inferred_rank == 'domain'
      "<i>#{name}</i>".html_safe
    else
      "&#8220;#{name}&#8221;".html_safe
    end
  end

  def name_html(name = nil)
    name ||= self.name
    if candidatus?
      name.gsub(/^Candidatus /, '<i>Candidatus</i> ').html_safe
    elsif validated? && name =~ /(.+) subsp\. (.+)/
      "<i>#{$1}</i> subsp. <i>#{$2}</i>".html_safe
    elsif validated? || inferred_rank == 'domain'
      "<i>#{name}</i>".html_safe
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
    y += " corrig." if corrigendum_by
    y += " #{proposed_by.short_citation}" if proposed_by
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
    return false if user.nil?
    return false if status >= 15
    return true if user.curator?
    return true if status == 5 && user?(user)
    false
  end

  def can_claim?(user)
    return false if user.nil?
    return false unless user.contributor? && created_by.nil?
    status <= 10
  end

  # ============ --- TAXONOMY --- ============

  def top_rank?
    rank.to_s == self.class.ranks.first
  end

  def expected_parent_rank
    idx = self.class.ranks.index(rank.to_s)
    self.class.ranks[idx - 1] if idx && idx > 0
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

  def expected_type_rank
    return nil if !rank? || %w[species subspecies domain].include?(rank)
    return 'species' if rank == 'genus'
    'genus'
  end

  def type_material_name
    self.class.type_material_hash[type_material.to_sym][:name] if type?
  end

  def type_text
    if type?
      @type_text ||= "#{type_material_name}: #{type_accession}"
    end
  end

  def possible_type_materials
    self.class.type_material_hash.select do |_, v|
      v[:sp] == (%w[species subspecies].include?(inferred_rank))
    end
  end

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
end
