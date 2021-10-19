class Name < ApplicationRecord
  has_many :publication_names, dependent: :destroy
  has_many :publications, through: :publication_names
  belongs_to :proposed_by, optional: true,
    class_name: 'Publication', foreign_key: 'proposed_by'
  belongs_to :corrigendum_by, optional: true,
    class_name: 'Publication', foreign_key: 'corrigendum_by'
  belongs_to :parent, optional: true, class_name: 'Name'
  belongs_to :created_by, optional: true,
    class_name: 'User', foreign_key: 'created_by'
  belongs_to :submitted_by, optional: true,
    class_name: 'User', foreign_key: 'submitted_by'
  belongs_to :validated_by, optional: true,
    class_name: 'User', foreign_key: 'validated_by'

  has_rich_text :description
  has_rich_text :notes
  has_rich_text :etymology_text
  
  validates :name, presence: true, uniqueness: true
  validates :syllabication,
    format: {
      with: /\A[A-Z\.'-]*\z/i,
      message: 'Only letters, dashes, dots, and apostrophe are allowed'
    }

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

    def rank_regexp
      { phylum: /ota$/, class: /ia$/, order: /ales$/, family: /aceae$/ }
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

  # ============ --- QUALITY CHECKS --- ============
  def qc_warnings
    return @qc_warnings unless @qc_warnings.nil?

    @qc_warnings = []
    return @qc_warnings if inferred_rank == 'domain'

    unless rank?
      @qc_warnings << {
        type: :missing_rank,
        message: 'The taxon has not been assigned a rank',
        link_text: 'Define rank',
        link_to: [:edit_name_rank_url, self],
        recommendations: %w[7],
        rules: %w[26.4]
      }
    end

    unless identical_base_name.nil?
      @qc_warnings << {
        type: :identical_base_name,
        message: 'Base name already exists with different qualifiers',
        link_text: identical_base_name.abbr_name,
        link_to: [:name_url, identical_base_name],
        link_public: true
      }
    end

    unless description?
      @qc_warnings << {
        type: :missing_description,
        message: 'The name has no registered description',
        link_text: 'Edit description',
        link_to: [:edit_name_url, self]
      }
    end

    if proposed_by.nil?
      @qc_warnings << {
        type: :missing_proposal,
        message: 'The publication proposing this name has not been identified',
        link_text: 'Register publication',
        link_to: [:new_publication_url, { link_name: id }]
      }
    end

    unless base_name =~ /\A[A-Z][a-z ]+\z/
      $qc_warnings << {
        type: :inconsistent_format,
        message: 'Names should only include Latin characters. ' +
                 'The first epithet must be capitalized, and other ' +
                 'epithets (if any) should be given in lower case',
        rules: %w[8 11 45]
      }
    end

    unless correct_suffix?
      @qc_warnings << {
        type: :incorrect_suffix,
        message: 'The ending of the name is incompatible with the rank of ' +
                 rank,
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: %w[15]
      }
    end

    unless type?
      @qc_warnings << {
        type: :missing_type,
        message: 'The name is missing a type definition',
        link_text: 'Edit type',
        link_to: [:edit_name_type_url, self],
        rules: %w[17 26.3]
      }
    end

    unless consistent_type_rank?
      @qc_warnings << {
        type: :inconsistent_type_rank,
        message: "The nomenclatural type of a #{rank} must " +
                 "be a designated #{expected_type_rank}",
        link_text: 'Edit type',
        link_to: [:edit_name_type_url, self],
        rules: %w[16]
      }
    end

    unless !rank? || top_rank? || !parent.nil?
      @qc_warnings << {
        type: :missing_parent,
        message: 'The taxon has not been assigned a higher classification',
        link_text: 'Link parent',
        link_to: [:name_link_parent_url, self],
        recommendations: [7]
      }
    end

    unless consistent_parent_rank?
      @qc_warnings << {
        type: :inconsistent_parent_rank,
        message: "The parent rank (#{parent.rank}) is inconsistent " +
                 "with the rank of this name (#{rank})",
        link_text: 'Edit parent',
        link_to: [:name_link_parent_url, self]
      }
    end

    if rank? && rank == 'species' && base_name !~ / /
      @qc_warnings << {
        type: :unary_species_name,
        message: 'Species must be binary names',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: [8, 10]
      }
    end

    if rank? && rank == 'subspecies' && base_name !~ /\A[A-Z][a-z]* [a-z]+ subsp\. [a-z]+/
      @qc_warnings << {
        type: :malformed_subspecies_name,
        message: 'Subspecies names should include the species name, ' +
                 'the abbreviation "subsp.", and the subspecies epithet',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: ['13a']
      }
    end

    if rank? && !%w[species subspecies].include?(rank) && base_name =~ / /
      @qc_warnings << {
        type: :binary_name_above_species,
        message: 'Names above the rank of species must be single words',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: [8]
      }
    end

    if rank? && rank == 'genus' && Name.rank_regexp.any? { |i| name =~ i }
      @qc_warnings << {
        type: :reserved_suffix,
        message: 'Avoid reserved suffixes for genus names',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        recommendations: [10]
      }
    end

    if last_epithet.size > 20
      @qc_warnings << {
        type: :long_name,
        message: 'Consider reducing the length of the name',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        recommendation: ['9.1']
      }
    end

    unless consistent_species_name?
      @qc_warnings << {
        type: :inconsistent_species_name,
        message: 'The first epithet of species names must correspond to the ' +
                 'parent genus',
        link_text: 'Edit parent',
        link_to: [:name_link_parent_url, self],
        rules: %w[8]
      }
    end

    unless consistent_subspecies_name?
      @qc_warnings << {
        type: :inconsistent_subspecies_name,
        message: 'The first two epithets of subspecies names must correspond to the ' +
                 'parent species',
        link_text: 'Edit parent',
        link_to: [:name_link_parent_url, self],
        rules: %w[13a]
      }
    end

    unless consistent_grammar_for_species_or_subspecies?
      @qc_warnings << {
        type: :"inconsistent_grammar_for_#{rank}_name",
        message: "A #{rank} name must be an adjective or a noun",
        link_text: 'Edit etymology',
        link_to: [:edit_name_etymology_url, self],
        rules: rank == 'species' ? %w[12] : %w[13b]
      }
    end

    unless consistent_name_for_subspecies_with_type?
      @qc_warnings << {
        type: :inconsistent_name_for_subspecies_with_type,
        message: 'A subspecies including the type of the species must have the same epithet',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: %w[13c]
      }
    end

    if etymology?
      if etymology(:p1, :grammar) && !etymology(:xx, :grammar)
        @qc_warnings << {
          type: :missing_full_epithet_etymology,
          message: 'The etymology of one or more particles is provided, but ' +
                   'the etymology of the full name or epithet is missing',
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          rules: %w[26.5]
        }
      end
    else
      @qc_warnings << {
        type: :missing_etymology,
        message: 'The etymology of the name has not been provided',
        link_text: 'Edit etymology',
        link_to: [:edit_name_etymology_url, self],
        rules: %w[26.5]
      }
    end

    unless consistent_grammatical_number_and_gender?
      case rank
      when 'genus'
        @qc_warnings << {
          type: :inconsistent_grammatical_number_or_gender,
          message: 'A genus must be given in the singular number',
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          rules: [10]
        }
      when 'species', 'subspecies'
        @qc_warnings << {
          type: :inconsitent_grammatical_number_or_gender,
          message: 'A specific epithet formed by an adjective ' +
                   'should agree in number and gender with the parent name',
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          recommendations: rank == 'species' ? %w[12.2] : %w[13b]
          # TODO Revise Rule 13b here, it should probably be a recommendation
        }
      when 'family', 'order'
        @qc_warnings << {
          type: :inconsitent_grammatical_number_or_gender,
          message: "A #{rank} name must be feminine and plural",
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          recommendations: %w[14]
        }
      when 'class', 'phylum'
        @qc_warnings << {
          type: :inconsitent_grammatical_number_or_gender,
          message: "A #{rank} name must be neuter and plural",
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          recommendations: %w[14]
        }
      end
    end

    @qc_warnings
  end

  def identical_base_name
    if candidatus?
      @identical_base_name ||= Name.where(name: base_name).first
    else
      @identical_base_name ||= Name.where(name: "Candidatus #{name}").first
    end
  end

  def correct_suffix?
    regexp = self.class.rank_regexp[rank.to_s.to_sym]
    return true if regexp.nil? # domain, genus, species, subspecies, undefined

    name =~ regexp
  end

  def top_rank?
    rank.to_s == self.class.ranks.first
  end

  def consistent_parent_rank?
    return true if !rank? || parent.nil? || !parent.rank?
    
    self.class.ranks.index(rank) == self.class.ranks.index(parent.rank) + 1
  end

  def consistent_type_rank?
    return true if !rank? || %w[species subspecies].include?(rank) || !type?

    type_name.rank == expected_type_rank
  end

  def consistent_species_name?
    return true if !rank? || rank != 'species' || parent.nil? || !parent.rank?

    base_name.sub(/ .*/) == parent.base_name
  end

  def consistent_subspecies_name?
    return true if !rank? || rank != 'subspecies' || parent.nil? || !parent.rank?

    base_name.sub(/ subsp\..*/) == parent.base_name
  end

  def consistent_grammatical_number_and_gender?
    return true if !rank? || !etymology(:xx, :grammar)

    case rank
    when 'genus'
      etymology(:xx, :grammar) !~ /(^| )pl(\.|ural)( |$)/
    when 'species', 'subspecies'
      par_g = parent&.etymology(:xx, :grammar)
      par_g ||= '' # Assume singular
      g = etymology(:xx, :grammar)
      par_plural = !!(par_g =~ /(^| )pl(\.|ural)( |$)/)
      plural = !!(g =~ /(^| )pl(\.|ural)( |$)/)
      return false unless par_plural == plural
      gen = [/(^| )masc(\.|uline)( |$)/, /(^| )fem(\.|inine)( |$)/, /(^| )neut(\.|er)( |$)/]
      gen.all? { |rx| !!(par_g =~ rx) == !!(g =~ rx) }
    when 'family', 'order'
      g = etymology(:xx, :grammar)
      return false unless g =~ /(^| )fem(\.|inine)( |$)/
      return false unless g =~ /(^| )pl(\.|ural)( |$)/
      true
    when 'class', 'phylum'
      g = etymology(:xx, :grammar)
      return false unless g =~ /(^| )neut(\.|er)( |$)/
      return false unless g =~ /(^| )pl(\.|ural)( |$)/
      true
    else
      true
    end
  end

  def consistent_grammar_for_species_or_subspecies?
    return true if !rank? || !%w[species subspecies].include?(rank) || !etymology(:xx, :grammar)

    case etymology(:xx, :grammar)
    when /(^| )adj(\.|ective)( |$)/
      true # Rule 12.1 for species, 13b for subspecies
    when /(^| )(n(\.|oun)|s(\.|ubst(\.|antive)))( |$)/
      true # Rule 12.2 / 12.3 for species, 13b for subspecies
    else
      false
    end
  end

  def consistent_name_for_subspecies_with_type?
    return true if !rank? || rank != 'subspecies' || !type? || !parent&.type?
    return true if type_text != parent.type_text
    return true if last_epithet == parent.last_epithet

    false
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

  # ============ --- ETYMOLOGY --- ============

  def last_epithet
    name.gsub(/.* /, '')
  end

  def etymology(component, field)
    component = component.to_sym
    component = :xx if component == :full
    field = field.to_sym
    if component == :xx && field == :particle
      last_epithet
    else
      y = send(:"etymology_#{component}_#{field}")
      y.nil? || y.empty? ? nil : y
    end
  end

  def etymology?
    return true if etymology_text?

    (Name.etymology_particles - [:xx]).any? do |i|
      Name.etymology_fields.any? { |j| etymology(i, j) }
    end
  end

  def full_etymology(html = false)
    if etymology_text?
      y = etymology_text.body
      return(html ? y : y.to_plain_text)
    end

    y = Name.etymology_particles.map do |component|
      partial_etymology(component, html)
    end.compact.join('; ')
    y.empty? ? nil : html ? y.html_safe : y
  end

  def partial_etymology(component, html = false)
    pre = [etymology(component, :lang), etymology(component, :grammar)].compact.join(' ')
    pre = nil if pre.empty?
    par = etymology(component, :particle)
    des = etymology(component, :description)
    if html
      pre = "<b>#{pre}</b>" if pre
      par = "<i>#{par}</i>" if par
    end
    y = [[pre, par].compact.join(' '), des].compact.join(', ')
    y.empty? ? nil : html ? y.html_safe : y
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
      elsif name =~ Name.rank_regexp[:family]
        'family'
      elsif name =~ Name.rank_regexp[:order]
        'order'
      elsif name =~ Name.rank_regexp[:class]
        if children.first&.inferred_rank&.== 'species'
          'genus'
        else
          'class'
        end
      elsif name =~ Name.rank_regexp[:phylum]
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
end
