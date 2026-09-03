module GenomesHelper
  def genome_accession_links(genome)
    content_tag(:span, (genome.db_name || genome.database) + ': ') +
    genome.links.map do |acc, link_urls|
      content_tag(:span, acc) +
      content_tag(:span, class: 'small') do
        content_tag(:span, ' [') +
        link_urls.map do |site, link|
          link_to(site, link, target: '_blank')
        end.inject { |a, b| a + content_tag(:span, ' | ') + b } +
        fa_icon('external-link-alt', class: 'small ml-2', title: 'External links') +
        ']'
      end
    end.inject { |a, b| a + content_tag(:span, ' • ', class: 'mx-1') + b }
  end
end
