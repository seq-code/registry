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
  has_many(:registers)
  has_many(:name_correspondences)

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
    family.to_s + ( given ? ", #{given}" : '' )
  end

  def full_name?
    family? && given?
  end

  def display_name
    full_name? ? full_name : "SeqCode user #{username}"
  end
end
