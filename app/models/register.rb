class Register < ApplicationRecord
  belongs_to(:user)
  belongs_to(:publication, optional: true)
  has_one_attached(:publication_pdf)
  has_one_attached(:supplementary_pdf)
  has_one_attached(:record_pdf)
  has_many(:names)
  has_rich_text(:notes)

  before_create(:assign_accession)

  def to_param
    accession
  end

  class << self
    def unique_accession
      require 'securerandom'
      require 'digest'

      o = "r:" + SecureRandom.urlsafe_base64(5).downcase
      o + Digest::SHA1.hexdigest(o)[-1]
    end
  end

  def acc_url(protocol = false)
    "#{'https://' if protocol}seqco.de/#{accession}"
  end

  def status_name
    validated? ? 'validated' : submitted? ? 'submitted' : 'draft'
  end

  def names_to_review
    @names_to_review ||= names.where(status: 10)
  end

  def can_edit?(user)
    return false if validated?
    return false unless user
    return true if user.curator?

    user.id == user_id && !submitted
  end

  def can_view?(user)
    return true if submitted? || validated?
    return false unless user

    user.curator? || user.id == user_id
  end

  private

  def assign_accession
    self.accession ||= self.class.unique_accession
  end
end
