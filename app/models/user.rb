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
    inverse_of: :nomenclature_reviewed_by,
    foreign_key: 'nomenclature_review_by_id', dependent: :nullify
  )
  has_many(
    :genomics_reviewed_for_names, class_name: 'Name',
    inverse_of: :genomics_reviewed_by,
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
    :updated_genomes, class_name: 'Genome', inverse_of: :validated_by,
    foreign_key: 'updated_by_id', dependent: :nullify
  )
  has_many(:notifications, -> { order(created_at: :desc) }, dependent: :destroy)
  has_many(
    :unseen_notifications, -> { where(seen: false).order(created_at: :desc) },
    class_name: 'Notification'
  )
  has_many(:contacts)

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

  def roles
    o = ['User']
    o << 'Contributor' if contributor?
    o << 'Curator' if curator?
    o << 'Admin' if admin?
    o << 'Editor' if editor?
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
end
