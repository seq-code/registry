class Register < ApplicationRecord
  belongs_to(:user)
  belongs_to(:publication, optional: true)
  belongs_to(
    :published_by, optional: true,
    class_name: 'User', foreign_key: 'published_by'
  )
  has_one_attached(:publication_pdf)
  has_one_attached(:supplementary_pdf)
  has_one_attached(:certificate_pdf)
  has_many(:names, -> { order('updated_at') })
  has_many(
    :register_correspondences, -> { order(:created_at) }, dependent: :destroy
  )
  has_many(:checks, through: :names)
  has_many(:check_users, -> { distinct }, through: :checks, source: :user)
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

  validates(:publication_id, presence: true, if: :validated?)
  validates(:publication_pdf, presence: true, if: :validated?)
  validates(:title, presence: true, if: :validated?)
  validate(:title_different_from_effective_publication)

  include HasObservers
  include Register::Status

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
      where(validated: false, notified: true)
        .or(where(validated: false, submitted: true))
        .order(updated_at: :asc)
        .select { |i| i.notified? || !i.endorsed? }
    end
  end

  def acc_url(protocol = false)
    "#{'https://' if protocol}seqco.de/#{accession}"
  end

  def names_by_rank
    names.sort do |a, b|
      Name.ranks.index(a.rank) <=> Name.ranks.index(b.rank)
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

  def can_edit?(user)
    return false if validated?
    return false unless user
    return true if user.curator?

    user.id == user_id # && !submitted
  end

  def can_view?(user)
    return true if submitted? || validated? || notified?
    return false unless user

    user.curator? || user.id == user_id
  end

  def can_view_publication?(user)
    return false unless user && publication_pdf.attached?

    user.curator? || user.id == user_id
  end

  def display
    'Register List %s' % accession
  end

  def proposing_publications
    @proposing_publications ||=
      Publication.where(id: names.pluck(:proposed_by))
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
    doi || ('10.57973/seqcode.%s' % accession)
  end

  def doi_url
    'https://doi.org/%s' % propose_doi
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
      names.pluck(:validated_by, :endorsed_by, :nomenclature_reviewer)
           .flatten.compact.uniq
  end

  def reviewers
    @reviewers ||= User.where(id: reviewer_ids)
  end

  def curators
    @curators ||= (check_users + reviewers).uniq
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
