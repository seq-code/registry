module GenomesHelper
  def genome_accession_links(genome)
    k = 0
    content_tag(:span, (genome.db_name || genome.database) + ':') +
    genome.links.map do |acc, link|
      content_tag(:span, (k += 1) > 1 ? '•' : '', class: 'mx-1') +
      link_to(link, target: '_blank') do
        content_tag(:span, acc) + fa_icon('external-link-alt', class: 'ml-2')
      end
    end.inject(:+)
  end
end
