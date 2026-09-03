module GenomesHelper
  def genome_accession_links(genome)
    content_tag(:span, (genome.db_name || genome.database) + ': ') +
    safe_join(
      genome.links.map do |acc, link_urls|
        content_tag(:span, acc) +
        content_tag(:span, class: 'small') do
          content_tag(:span, ' [') +
          safe_join(
            link_urls.map { |site, link| link_to(site, link, target: '_blank') },
            content_tag(:span, ' | ')
          ) +
          fa_icon('external-link-alt', class: 'small ml-2', title: 'External links') +
          ']'
        end
      end,
      content_tag(:span, ' • ', class: 'mx-1')
    )
  end
end
