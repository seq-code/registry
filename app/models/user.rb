class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable
  validates :username, uniqueness: true, presence: true

  def self.contributor_applications
    where( 'contributor_statement is not null' ).where( contributor: false )
  end

  def roles
    ['User'] + (admin? ? ['Admin'] : []) + (contributor? ? ['Contributor'] : [])
  end

  def to_param
    username
  end
end
