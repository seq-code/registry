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
  has_many(:register_correspondences, dependent: :destroy)
  alias :correspondences :register_correspondences
  has_rich_text(:notes)
  has_rich_text(:abstract)
  has_rich_text(:submitter_authorship_explanation)

  before_create(:assign_accession)

  validates(:publication_id, presence: true, if: :validated?)
  validates(:publication_pdf, presence: true, if: :validated?)
  validates(:title, presence: true, if: :validated?)

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
  end

  def acc_url(protocol = false)
    "#{'https://' if protocol}seqco.de/#{accession}"
  end

  def status_name
    validated? ? 'validated' : notified? ? 'notified' :
                               submitted? ? 'submitted' : 'draft'
  end

  def draft?
    status_name == 'draft'
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

  def can_edit?(user)
    return false if validated?
    return false unless user
    return true if user.curator?

    user.id == user_id && !submitted
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

  def proposing_publications
    @proposing_publications ||=
      Publication.where(id: names.pluck(:proposed_by))
                 .where('journal IS NOT NULL')
                 .where.not(pub_type: 'posted-content')
  end

  def propose_title
    return title if title?

    case names.size
    when 0
      'Empty register List %s' % acc_url
    when 1
      self.class.nom_nov(names.first)
    when 2

      # TODO Handle special (common) case of a species
      # name proposed with its genus: we can simply
      # use the species name sp. nov. gen. nov.

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

  def propose_doi
    '10.25651/seqcode.%s' % accession
  end

  def citations
    @citations ||=
      ([publication] + sorted_names.map(&:citations).flatten).compact.uniq
  end

  ##
  # Automated checks to prepare for validation, adding relevant notes
  # to the list
  def automated_validation
    # Trivial cases (not-yet-notified or already validated)
    return false unless notified?
    return true if validated?

    # Minimum requirements
    success = true
    unless publication && publication_pdf.attached?
      add_note('Missing publication or PDF files')
      success = false
    end

    # Check that all names have been approved
    unless names.all?(&:after_approval?)
      add_note('Some names have not been approved yet')
      success = false
    end

    # Check if the list has a PDF that includes the accession
    has_acc = false
    bnames = Hash[names.map { |n| [n.base_name, false] }]
    cnames = Hash[names.map { |n| [n.base_name, n.corrigendum_from] }]
    [publication_pdf, supplementary_pdf].each do |as|
      break if has_acc && bnames.values.all?
      next unless as.attached?

      as.open do |file|
        render = PDF::Reader.new(file.path)
        render.pages.each do |page|
          txt = page.text
          has_acc = true if txt.index(accession)
          bnames.each_key do |bn|
            if txt.index(bn) || (cnames[bn] && txt.index(cnames[bn]))
              bnames[bn] = true
            end
          end
          break if has_acc && bnames.values.all?
        end
      end
    end

    if has_acc
      add_note('The effective publication includes the SeqCode accession')
    else
      add_note(
        'The effective publication does not include the accession ' \
        '(SeqCode, Rule 26, Note 2)'
      )
    end

    if bnames.values.all?
      add_note('The effective publication mentions all names in the list')
    elsif bnames.values.any?
      if bnames.values.count(&:!) > 5
        add_note(
          "The effective publication mentions" \
            " #{bnames.values.count(&:itself)} out of" \
            " #{bnames.count} names in the list"
        )
      else
        add_note(
          "The effective publication mentions some names in the list," \
            " but not: #{bnames.select { |_, v| !v }.keys.join(', ')}"
        )
      end
    else
      add_note(
        'The effective publication does not mention any names in the list'
      )
    end

    save
  end

  def add_note(note, title = 'Auto-check')
    self.notes.body = <<~TXT
      #{notes.body}
      <b>#{title}:</b> #{note}
      <br/>
    TXT
  end

  def validate!(user)
    ActiveRecord::Base.transaction do
      par = { validated_by: user, validated_at: Time.now }
      names.each { |name| name.update!(par.merge(status: 15)) }
      update!(par.merge(notes: nil, validated: true))
    end

    HeavyMethodJob.perform_later(:post_validation, @register)
    true
  end

  ##
  # Production tasks to be executed once a list is validated
  def post_validation
    # TODO Produce and attach the certificate in PDF
    # TODO Distribute the certificate to mirrors
    # TODO Notify submitter
  end

  def all_approved?
    names.all?(&:after_approval?)
  end

  private

  def assign_accession
    self.accession ||= self.class.unique_accession
  end
end
