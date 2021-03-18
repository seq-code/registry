require 'serrano'

class Publication < ApplicationRecord
  default_scope { order(journal_date: :desc) }

  has_many :publication_authors, dependent: :destroy
  has_many :publication_subjects, dependent: :destroy
  has_many :publication_names, dependent: :destroy
  has_many :authors, -> { order('publication_authors.id ASC') },
    through: :publication_authors
  has_many :subjects, through: :publication_subjects
  has_many :names, through: :publication_names
  has_many :proposed_names, class_name: 'Name',
    inverse_of: :proposed_by, dependent: :destroy

  def self.by_doi(doi, force_update = false)
    if doi.nil? or doi.empty?
      return Publication.new.tap{ |i| i.errors.add(:doi, 'cannot be empty') }
    end
    p = Publication.find_by(doi: doi)
    return p if p && !force_update
    begin
      works = Serrano.works(ids: doi)
    rescue Serrano::NotFound
      return Publication.new.tap{ |i| i.errors.add(:doi, 'not in CrossRef') }
    end
    work = works[0].fetch('message', {})
    by_serrano_work(work) if work['DOI']
  end

  def self.by_serrano_work(work)
    journal_loc = "#{work['volume']}"
    journal_loc += " (#{work['issue']})" if work['issue']
    params = {
      title: (work['title'] || []).join('. '),
      journal: (work['container-title'] || []).join('. '),
      journal_loc: journal_loc,
      journal_date: Date.new(*work['created']['date-parts'].first),
      doi: work['DOI'],
      url: work['URL'],
      pub_type: work['type'],
      abstract: work['abstract'],
      crossref_json: work.to_json
    }
    p = Publication.find_by(doi: work['DOI'])
    if p
      p.update(params)
    else
      p = Publication.new(params)
      p.save or return p
    end

    work.fetch('subject', []).each do |subject|
      next unless subject
      s = Subject.find_by(name: subject)
      next if s and p.subjects.include? s
      s ||= Subject.new(name: subject).tap{ |i| i.save }
      PublicationSubject.
        new(publication_id: p.id, subject_id: s.id).save
    end

    work.fetch('author', []).each do |author|
      author['family'] ||= author['name']
      next unless author['family']

      a = Author.find_or_create(author['given'], author['family'])
      next if p.authors.include? a

      PublicationAuthor.
        new(publication_id: p.id, author_id: a.id,
          sequence: author['sequence']).save
    end
    p
  end

  def authors_et_al
    if authors.count < 3
      authors.pluck(:family).join(', ')
    else
      authors.pluck(:family).first + ', et al'
    end
  end

  def clean_abstract
    abstract.gsub(/<[^>]+>/, '') if abstract
  end

  def short_citation
    "#{authors_et_al} (#{journal_date.year})"
  end

  def citation
    "#{short_citation}, #{journal || pub_type.tr('-', ' ')}"
  end

  def emended_names
    publication_names.where(emends: true).map(&:name)
  end
end
