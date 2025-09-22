class Register < ApplicationRecord
  belongs_to(:user)
  belongs_to(:publication, optional: true)
  belongs_to(
    :published_by, optional: true,
    class_name: 'User', foreign_key: 'published_by_id'
  )
  belongs_to(
    :validated_by, optional: true,
    class_name: 'User', foreign_key: 'validated_by_id'
  )
  has_one_attached(:publication_pdf)
  has_one_attached(:supplementary_pdf)
  has_one_attached(:certificate_pdf)
  has_many(:names)
  has_many(
    :register_correspondences, -> { order(:created_at) }, dependent: :destroy
  )
  has_many(:checks, through: :names)
  has_many(:check_users, -> { distinct }, through: :checks, source: :user)
  has_many(
    :type_genomes, through: :names, source: :nomenclatural_type,
    source_type: 'Genome'
  )
  has_many(
    :type_names, through: :names, source: :nomenclatural_type,
    source_type: 'Name'
  )
  has_many(
    :type_strains, through: :names, source: :nomenclatural_type,
    source_type: 'Strain'
  )
  alias :correspondences :register_correspondences
  alias :created_by :user
  has_many(:observe_registers, dependent: :destroy)
  has_many(:observers, through: :observe_registers, source: :user)
  has_rich_text(:notes)
  has_rich_text(:abstract)
  has_rich_text(:submitter_authorship_explanation)

  before_create(:assign_accession)
  before_validation(:propose_and_save_title, if: :submitted?)
  before_destroy(:return_names_to_draft)
  before_save(:update_name_order)
  after_save(:unsnooze_curation!)

  validates(:publication_id, presence: true, if: :validated?)
  validates(:publication_pdf, presence: true, if: :validated?)
  validates(:title, presence: true, if: :validated?)
  validate(:title_different_from_effective_publication)

  include HasObservers
  include Register::Status
  include Register::SampleSet

  attr_accessor :modal_form_id

  def to_param
    accession
  end

  class << self
    def unique_accession
      require 'securerandom'
      require 'digest'

      o = 'r:' + SecureRandom.urlsafe_base64(5).downcase
      o + Digest::SHA1.hexdigest(o)[-1]
    end

    def nom_nov(name)
      o = name.name + ' '
      o +=
        case name.inferred_rank
        when 'subspecies';  'subsp.'
        when 'species';     'sp.'
        when 'genus';       'gen.'
        when 'family';      'fam.'
        when 'order';       'ord.'
        when 'class';       'classis'
        when 'phylum';      'phy.'
        else;               'nom.'
        end
      o + ' nov.'
    end

    def pending_for_curation
      where(validated: false)
        .where('notified = ? OR submitted = ?', true, true)
        .where('snooze_curation is null or snooze_curation <= ?', Time.now)
        .order(updated_at: :asc)
        .select { |i| i.notified? || !i.endorsed? }
    end

    def snoozed_for_curation
      where('snooze_curation > ?', Time.now)
        .order(updated_at: :asc)
    end
  end

  def acc_url(protocol = false)
    "#{'https://' if protocol}seqco.de/#{accession}"
  end

  def uri
    acc_url(true)
  end

  ##
  # Sort first by rank, and then alphabetically
  def names_by_rank
    names.sort do |a, b|
      y = Name.ranks.index(a.rank) <=> Name.ranks.index(b.rank)
      y.zero? ? a.base_name <=> b.base_name : y
    end
  end

  alias :sorted_names :names_by_rank

  def names_to_review
    @names_to_review ||= names.where(status: 10)
  end

  def priority_date
    return nil unless validated?

    notified_at || validated_at
  end

  def last_submission_date
    [notified_at, submitted_at].compact.max || names.pluck(:submitted_at).max
  end

  def correct_reviewer_token?(token)
    token.present? && token == reviewer_token
  end

  def user?(user)
    user && user_id == user.id
  end
  alias :created_by? :user?

  def can_edit?(user)
    return false if validated?
    return false unless user
    return true if user.curator?

    user?(user) # && !submitted
  end

  def can_view?(user, token = nil)
    return true if submitted? || validated? || notified?
    return true if correct_reviewer_token?(token)
    return false unless user

    user.curator? || user?(user)
  end

  def can_view_publication?(user)
    return false unless user && publication_pdf.attached?

    user.curator? || user?(user)
  end

  def can_view_correspondence?(user)
    can_edit?(user) || (!published? && user?(user))
  end

  def display(_html = true)
    'Register List %s' % accession
  end

  def proposing_publications
    @proposing_publications ||=
      Publication.where(id: names.pluck(:proposed_in_id))
                 .where('journal IS NOT NULL')
                 .where.not(pub_type: 'posted-content')
  end

  def propose_title
    return title if title?

    if names_at_rank(:species).size == 1 &&
       names_at_rank(:subspecies).empty? &&
       single_lineage?
      return(
        case names.size
        when 1
          self.class.nom_nov(names.first)
        when 2
          <<~TITLE
            #{names_at_rank(:species).first.name} \
            gen. nov. sp. nov.
          TITLE
        when 3
          <<~TITLE
            Register list for \
            #{names_at_rank(:species).first.name} \
            gen. nov. sp. nov. and \
            #{names_at_rank(:family).first.name} fam. nov.
          TITLE
        else
          <<~TITLE
            Register list for \
            #{names_at_rank(:species).first.name} \
            gen. nov. sp. nov. and their lineage
          TITLE
        end
      )
    end

    case names.size
    when 0
      'Empty register List %s' % acc_url
    when 1
      self.class.nom_nov(names.first)
    when 2
      <<~TITLE
        #{self.class.nom_nov(names.first)} and \
        #{self.class.nom_nov(names.second)}
      TITLE
    else
      <<~TITLE
        Register list for #{names.size} new names \
        including #{self.class.nom_nov(names.first)}
      TITLE
    end
  end

  def title_has_wrong_number_of_names?
    return false unless title?
    m = title.match(/\s(\d+)\s+(new\s+)?names?\s/) or return false
    in_title = m[1].to_i
    in_title != 0 && in_title != names.size
  end

  ##
  # The list contains *only* a novel species and (optionally)
  # their parent taxa. If one or more subspecies within the species
  # are included, the test is still +true+, unless the total number
  # of names exceedes 9. It's always true for lists with a single
  # name.
  def single_lineage?
    return true if names.size == 1
    return false unless (2..9).include? names.size
    return false if names_at_rank(:species).size != 1

    top = names.filter { |n| !names.include? n.parent }
    top.size == 1
  end

  ##
  # Returns and Array the names in the list with specified +rank+
  def names_at_rank(rank)
    names.filter { |n| n.inferred_rank.to_sym == rank.to_sym }
  end

  def propose_doi
    published_doi ||
      '%s/seqcode.%s' % [Rails.configuration.datacite[:prefix], accession]
  end

  alias :doi :propose_doi

  def doi_url
    'https://doi.org/%s' % doi
  end

  def snoozed_curation?
    snooze_curation.present? && snooze_curation > Time.now
  end

  def snooze_curation!(time)
    time = nil if time && time <= Time.now
    update_column(:snooze_curation, time)
  end

  def unsnooze_curation!
    snooze_curation!(nil)
  end

  def citations
    @citations ||=
      ([publication] + sorted_names.map(&:citations).flatten).compact.uniq
  end

  def add_note(note, title = 'Auto-check')
    self.notes.body = <<~TXT
      #{notes.body}
      <b>#{title}:</b> #{note}
      <br/>
    TXT
  end

  def reviewer_ids
    @reviewer_ids ||=
      names.pluck(:validated_by_id, :endorsed_by_id,
                  :nomenclature_review_by_id, :genomics_review_by_id)
           .flatten.compact.uniq
  end

  def reviewers
    @reviewers ||= User.where(id: reviewer_ids)
  end

  def curators
    @curators ||= (check_users + reviewers).uniq - [user]
  end

  def nomenclature_review_by?(user)
    names.pluck(:nomenclature_review_by_id).include? user.id
  end

  def genomics_review_by?(user)
    names.pluck(:genomics_review_by_id).include? user.id
  end

  def observing?(user)
    observe_registers.where(user: user).present?
  end

  ##
  # Attempts to add an observer while silently ignoring it if the user
  # already observes the register
  def add_observer(user)
    self.observers << user
  rescue ActiveRecord::RecordNotUnique
    true
  end

  def corresponding_users
    correspondences.map(&:user).uniq
  end

  def associated_users
    (
      [user, validated_by, published_by] +
      corresponding_users
    ).compact.uniq
  end

  def all_review?
    genomics_review && nomenclature_review
  end

  def update_name_order
    names.map(&:update_name_order)
  end

  def tree
    @tree ||= fresh_tree
  end

  def fresh_tree
    {}.tap do |o|
      names.order(:name_order).each do |name_i|
        y = o
        name_i.lineage(with_self: true).each { |name_j| y = (y[name_j] ||= {}) }
      end
    end
  end

  def registers_with_shared_publication
    return unless publication.present?
    if validated?
      publication.registers.where(validated: true) - [self]
    else
      publication.registers - [self]
    end
  end

  def merge_into(main_register, user)
    # Assertions
    errors.add(
      :accession, 'can\'t merge non-register object with a register'
    ) unless main_register.is_a? self.class
    errors.add(
      :accession, 'can\'t merge register with itself'
    ) if self == main_register
    errors.add(
      :validated, 'can\'t merge validated registers'
    ) unless !validated? && !main_register.validated?
    errors.add(
      :user, 'user doesn\'t have sufficient register privileges'
    ) unless can_edit?(user) && main_register.can_edit?(user)
    errors.add(
      :user, 'can\'t merge register lists from different users'
    ) unless self.user == main_register.user
    errors.add(
      :publication,
      'can\'t merge registers with different effective publications'
    ) unless publication == main_register.publication
    errors.add(
      :names, 'nothing to merge, empty register'
    ) unless names.present?
    errors.add(
      :names, 'user doesn\'t have sufficient name privileges'
    ) unless names.all? { |name| name.can_edit?(user) }
    return if errors.any?

    # Transfer names and comment in both registers
    self.class.transaction do
      names.each { |name| name.update(register: main_register) }
      RegisterCorrespondence.new(
        message: 'Register list transferred to: %s' % main_register.acc_url,
        notify: '0', automatic: true, user: user, register: self
      ).save
      RegisterCorrespondence.new(
        message: 'Register list imported: %s' % self.acc_url,
        notify: '0', automatic: true, user: user, register: main_register
      ).save
    end
  end

  def wikispecies_issues?
    names.any? { |n| n.wikispecies_issues.any? }
  end

  def pending_genomes?
    names.any? { |n| n.type_genome.try(:pending?) }
  end

  private

  def assign_accession
    self.accession ||= self.class.unique_accession
  end

  def title_different_from_effective_publication
    if title && publication && title == publication.title
      errors.add(
        :title, 'can\'t be the same as the title of the effective publication'
      )
      return true
    end
  end

  def propose_and_save_title
    self.title = propose_title unless title?
  end

  def return_names_to_draft
    names.each { |name| name.update(status: 5) if name.in_curation? }
  end
end
