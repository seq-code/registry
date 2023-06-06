class User < ApplicationRecord
  devise(
    :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :confirmable, :lockable, :trackable
  )

  has_many(:created_names, class_name: 'Name', foreign_key: 'created_by')
  has_many(:submitted_names, class_name: 'Name', foreign_key: 'submitted_by')
  has_many(:approved_names, class_name: 'Name', foreign_key: 'approved_by')
  has_many(:validated_names, class_name: 'Name', foreign_key: 'validated_by')
  has_many(
    :nomenclature_reviewed_for_names,
    class_name: 'Name', foreign_key: 'nomenclature_reviewer'
  )
  has_many(:registers)
  has_many(:name_correspondences)
  has_many(:register_correspondences)
  has_many(:tutorials)

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
end
