module PlacementsHelper
  def placement_preference(placement)
    return unless placement

    taxonomies = %i[ncbi gtdb]
    taxonomies.map do |t|
      preferred_taxonomy(t) if placement.send("#{t}_taxonomy")
    end.compact.inject(:+)
  end

  def preferred_taxonomy(scheme)
    @preferred_taxonomy_modals ||= {}
    tax = {
      ncbi: [
        'NCBI Taxonomy', 'https://www.ncbi.nlm.nih.gov/taxonomy',
        'January / 2024'
      ],
      gtdb: [
        'Genome Taxonomy Database', 'https://gtdb.ecogenomic.org/',
        'r214.1 (June / 2023)'
      ]
    }
    @preferred_taxonomy_modals[scheme] ||= modal(tax[scheme][0]) do
      content_tag(:span, 'This is the preferred assignment in ') +
      link_to(tax[scheme][1], target: '_blank') do
        content_tag(:span, tax[scheme][0] + ' ') + fa_icon('external-link-alt')
      end +
      content_tag(:span, ', as captured in ' + tax[scheme][2]) +
      content_tag(:sup, 1) +
      content_tag(:hr, nil, class: 'mt-4') +
      content_tag(:span, class: 'text-muted small') do
        <<~HELP.html_safe
          <b>1.</b> No single "official" taxonomy of prokaryotes exists, and
          <b>Principle 1</b> of the SeqCode indicates that "nothing in the
          SeqCode may be construed to restrict the freedom of taxonomic opinion
          or action". However, some well-curated taxonomic schemes exist that
          can help authors navigate the complex relationships in prokaryotic
          systematics, and the SeqCode Registry captures and presents some
          schemes as a service to the community.
        HELP
      end
    end
    modal_button(
      @preferred_taxonomy_modals[scheme],
      class: 'badge badge-pill badge-info mx-1'
    ) { fa_icon('star', class: 'mr-1 small') + scheme.to_s }
  end
end
