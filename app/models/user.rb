class User < ApplicationRecord
  devise(
    :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :confirmable, :lockable, :trackable
  )

  has_many(
    :created_names, class_name: 'Name', foreign_key: 'created_by_id',
    inverse_of: :created_by, dependent: :nullify
  )
  has_many(
    :submitted_names, class_name: 'Name', foreign_key: 'submitted_by_id',
    inverse_of: :submitted_by, dependent: :nullify
  )
  has_many(
    :endorsed_names, class_name: 'Name', foreign_key: 'endorsed_by_id',
    inverse_of: :endorsed_by, dependent: :nullify
  )
  has_many(
    :validated_names, class_name: 'Name', foreign_key: 'validated_by_id',
    inverse_of: :validated_by, dependent: :nullify
  )
  has_many(
    :nomenclature_reviewed_for_names, class_name: 'Name',
    inverse_of: :nomenclature_review_by,
    foreign_key: 'nomenclature_review_by_id', dependent: :nullify
  )
  has_many(
    :genomics_reviewed_for_names, class_name: 'Name',
    inverse_of: :genomics_review_by,
    foreign_key: 'genomics_review_by_id', dependent: :nullify
  )
  has_many(
    :validated_registers, class_name: 'Register', inverse_of: :validated_by,
    foreign_key: 'validated_by_id', dependent: :nullify
  )
  has_many(
    :published_registers, class_name: 'Register', inverse_of: :published_by,
    foreign_key: 'published_by_id', dependent: :nullify
  )
  has_many(:registers, dependent: :nullify)
  has_many(:name_correspondences, dependent: :nullify)
  has_many(:register_correspondences, dependent: :nullify)
  has_many(:tutorials, dependent: :nullify)
  has_many(:checks, dependent: :nullify)
  has_many(:checked_names, -> { distinct }, through: :checks, source: :name)
  has_many(:observe_names, dependent: :destroy)
  has_many(:observing_names, through: :observe_names, source: :name)
  has_many(:observe_registers, dependent: :destroy)
  has_many(:observing_registers, through: :observe_registers, source: :register)
  has_many(
    :updated_genomes, class_name: 'Genome', inverse_of: :updated_by,
    foreign_key: 'updated_by_id', dependent: :nullify
  )
  has_many(:notifications, -> { order(created_at: :desc) }, dependent: :destroy)
  has_many(
    :unseen_notifications, -> { where(seen: false).order(created_at: :desc) },
    class_name: 'Notification'
  )
  has_many(:contacts)
  has_many(:reports)
  has_many(:curations)
  has_one(:wikispecies_credential, dependent: :destroy)

  validates(
    :username,
    uniqueness: true,
    presence: true,
    format: {
      with: /\A[A-Za-z0-9_]+\z/, message: 'only alphanumerics and underscores'
    }
  )

  def self.contributor_applications
    where('contributor_statement is not null').where(contributor: false)
  end

  def self.curator_applications
    where('curator_statement is not null').where(curator: false)
  end

  def self.community_member_applications
    where.not(community_member_applied_at: nil)
  end

  def self.community_members_active
    where(community_member: true)
      .where('community_member_expires_on >= ?', Date.current)
  end

  FIRST_COMMUNITY_MEMBERSHIP_COHORT_END = Date.new(2026, 12, 31)

  ##
  # End date of the SeqCode Community membership cohort a new grant made on
  # +date+ should belong to, computed forward from
  # +FIRST_COMMUNITY_MEMBERSHIP_COHORT_END+ in 4-year blocks. If +date+ falls
  # within the last six months of a cohort (i.e., the reapply window), the
  # next cohort is returned instead, so applying or renewing near the end of
  # a cohort grants the full next term rather than a few leftover months
  def self.community_membership_cohort_end(date = Date.current)
    cohort_end = FIRST_COMMUNITY_MEMBERSHIP_COHORT_END
    cohort_end += 4.years while cohort_end < date
    cohort_end += 4.years if cohort_end - 6.months <= date
    cohort_end
  end

  COMMUNITY_MEMBER_POSITION_OPTIONS = [
    'Graduate Student',
    'Postdoctoral fellow',
    'Research Assistant, Research Faculty, Project Leader, or equivalent',
    'Assistant Professor or equivalent',
    'Associate Professor or equivalent',
    'Full Professor or equivalent',
    'Emeritus Professor'
  ].freeze

  COMMUNITY_MEMBER_DEGREE_OPTIONS = [
    'Bachelor in Science or equivalent',
    'Master in Science or equivalent',
    'Doctor in Philosophy or equivalent',
    'Medical Doctor or equivalent'
  ].freeze

  def self.find_by_email_or_username(query)
    where('LOWER(email) = ?', query.downcase).or(where(username: query)).first
  end

  def roles
    o = ['User']
    o << 'Contributor' if contributor?
    o << 'Curator' if curator?
    o << 'Admin' if admin?
    o << 'Editor' if editor?
    o << 'Officer' if officer?
    o
  end

  def to_param
    username
  end

  def full_name
    family.to_s + (given ? ", #{given}" : '')
  end

  def full_name?
    family? && given?
  end

  def display_name
    full_name? ? full_name : "SeqCode user #{username}"
  end

  def informal_name
    given? ? given : username
  end

  def orcid_url
    orcid? ? "https://orcid.org/#{orcid}" : nil
  end

  def ror_url
    affiliation_ror? ? "https://ror.org/#{affiliation_ror}" : nil
  end

  def ror_2_url
    affiliation_2_ror? ? "https://ror.org/#{affiliation_2_ror}" : nil
  end

  def academic_email?
    uni_dom = Rails.root.join('lib', 'uni-domains.txt')
    File.open(uni_dom, 'r') do |fh|
      fh.each do |ln|
        return true if email.downcase =~ /[@\.]#{Regexp.quote(ln.chomp)}\z/
      end
    end

    false
  end

  def reviewed_names
    @reviewed_names ||=
      Name.where(
        'validated_by_id = ? OR endorsed_by_id = ? ' \
        'OR nomenclature_review_by_id = ? OR genomics_review_by_id = ?',
        id, id, id, id
      )
  end

  def curated_names
    @curated_names ||= (checked_names + reviewed_names).uniq
  end

  ##
  # Is the user currently a SeqCode Community member, i.e., granted and not
  # past the end of the cohort they were granted through?
  def community_member_active?
    community_member? && community_member_expires_on.present? &&
      community_member_expires_on >= Date.current
  end

  ##
  # Can the user (re)apply for SeqCode Community membership right now? Always
  # true before a first application; renewals are only open in the six
  # months before (or after) the current membership expires
  def can_apply_for_community_membership?
    return true if community_member_expires_on.blank?

    Date.current >= community_member_expires_on - 6.months
  end

  ##
  # Is the community member profile filled in with everything required to
  # apply for or renew SeqCode Community membership?
  def community_member_profile_complete?
    given? && family? && affiliation? && department? && position? &&
      highest_degree? && achievements? && membership_societies?
  end
end
