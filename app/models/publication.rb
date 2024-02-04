require 'serrano'

class Publication < ApplicationRecord
  default_scope { order(journal_date: :desc) }

  has_many(
    :publication_authors, -> { order('publication_authors.id ASC') },
    dependent: :destroy
  )
  has_many(:publication_subjects, dependent: :destroy)
  has_many(:publication_names, dependent: :destroy)
  has_many(:authors, through: :publication_authors)
  has_many(:subjects, through: :publication_subjects)
  has_many(:names, through: :publication_names)
  has_many(
    :proposed_names, class_name: 'Name',
    foreign_key: 'proposed_in_id', inverse_of: :proposed_in,
    dependent: :nullify
  )
  has_many(
    :corrigendum_names, class_name: 'Name',
    foreign_key: 'corrigendum_in_id', inverse_of: :corrigendum_in,
    dependent: :nullify
  )
  has_many(
    :assigned_names, class_name: 'Name',
    foreign_key: 'assigned_in_id', inverse_of: :assigned_in,
    dependent: :nullify
  )
  has_many(:placements, dependent: :nullify)

  class << self

    def by_doi(doi, force_update = false)
      if doi.nil? || doi.empty?
        return Publication.new.tap { |i| i.errors.add(:doi, 'cannot be empty') }
      end
      p = Publication.find_by(doi: doi)
      return p if p && !force_update

      begin
        works = Serrano.works(ids: doi)
      rescue Serrano::NotFound
        return Publication.new.tap { |i| i.errors.add(:doi, 'not in CrossRef') }
      end

      work = works[0].fetch('message', {})
      by_serrano_work(work) if work['DOI']
    end

    def by_serrano_work(work)
      journal_loc = "#{work['volume']}"
      journal_loc += " (#{work['issue']})" if work['issue']
      date_h = work['published-print'] || work['published'] ||
               work['published-online'] || work['created']
      params = {
        title: (work['title'] || []).join('. '),
        journal: (work['container-title'] || []).join('. '),
        journal_loc: journal_loc,
        journal_date: Date.new(*date_h['date-parts'].first),
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

    def query_crossref(query)
      publications = []
      query[:offset] ||= 0

      loop do
        works = Serrano.works(**query)

        unless works['status'] == 'ok'
          raise "#{works['message-type']}: " +
            works['message'].map { |i| i['message'] }.join('; ')
        end

        # Parse results
        works['message']['items'].each do |work|
          p = Publication.by_serrano_work(work)
          p.new_record? and
            raise "Cannot save doi:#{work['DOI']}:\n#{p.errors.join("\n")}"
          publications << p
          yield(p) if block_given?
        end

        # Continue
        query[:offset] += 20
        break if query[:offset] > works['message']['total-results']
      end

      publications
    end

  end

  def authors_et_al
    family = authors.pluck(:family) # To reduce SQL requests
    if family.empty?
      'Anonymous'
    elsif family.count < 3
      family.join(', ')
    else
      family.first + ' et al.'
    end
  end

  def authors_et_al_html
    ERB::Util.h(authors_et_al)
  end

  def clean_abstract
    if abstract?
      @clean_abstract ||= abstract.gsub(/<([^>]+>|script[^>]+>?)/, '')
    end
  end

  def short_citation
    "#{authors_et_al}, #{journal_date.year}"
  end

  def citation
    "#{short_citation}, #{journal || pub_type.tr('-', ' ')}"
  end

  def journal_html
    ERB::Util.h(journal || '[%s]' % pub_type.tr('-', ' '))
  end

  def long_citation_html
    <<~HTML.html_safe
      #{authors_et_al_html} (#{journal_date.year}). #{title_html}. 
      <i>#{journal_html}</i>. <a href="#{link}" target="_blank">DOI:#{doi}</a>
    HTML
  end

  def title_html
    ERB::Util.h(title)
      .gsub(/(?:&|\\u0026|&amp;)lt;(\/?(?:i|em))(?:&|\\u0026|&amp;)gt;/, '<\1>')
      .gsub(/\.$/, '')
      .html_safe
  end

  def emended_names
    publication_names.where(emends: true).map(&:name)
  end

  def prepub?
    !journal? || pub_type == 'posted-content'
  end

  def link
    "https://doi.org/#{doi}"
  end

  def doi_title(html = true)
    html ? "#{doi}: #{title_html}" : "#{doi}: #{title}"
  end

  def include_term?(term)
    title.to_s.include?(term) || abstract.to_s.include?(term)
  end
end
