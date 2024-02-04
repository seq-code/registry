module PublicationsHelper
  def publication_full_citation(publication)
    content_tag(:span, publication.authors_et_al_html) +
    content_tag(:span, ' (%i). ' % publication.journal_date.year) +
    if publication.journal.empty?
      content_tag(:span, publication.journal_html, class: 'text-muted')
    else
      content_tag(:em) do
        link_to(publication.journal, journal_path(publication.journal))
      end + ' ' +
      publication.journal_loc
    end
  end
end
