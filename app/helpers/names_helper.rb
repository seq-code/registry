module NamesHelper
  def link_to_name_type(name)
    if name.type_is_name?
      if name.type_name
        link_to(name.type_name) { name.type_name.name_html }
      else
        content_tag(:span, "Illegal name: #{name.type_accession}", class: 'text-danger')
      end
    elsif name.type_genome
      link_to(name.type_genome.text, name.type_genome)
    elsif name.type_link
      # This section is currently not being used, it was meant for direct
      # external links in genomes, but now genomes have dedicated pages
      link_to(name.type_link, target: '_blank') do
        content_tag(:span, name.type_text) +
          fa_icon('external-link-alt', class: 'ml-1')
      end
    elsif name.type_is_strain?
      ext  = '<sup class="fas fa-external-link-alt "> </sup>'
      collections = {
        DSM:  'https://www.dsmz.de/collection/catalogue/details/culture/DSM-',
        JCM:  'https://www.jcm.riken.jp/cgi-bin/jcm/jcm_number?JCM=',
        KCTC: 'https://kctc.kribb.re.kr/collection/view?sn=',
        ATCC: 'https://www.atcc.org/products/',
        BCRC: 'https://catalog.bcrc.firdi.org.tw/BcrcContent?bid=',
        LMG:  'https://bccm.belspo.be/catalogues/lmg-strain-details?NUM=',
        NBRC: 'https://www.nite.go.jp/nbrc/catalogue/' \
              'NBRCCatalogueDetailServlet?ID=IFO&CAT=',
        IFO:  'https://www.nite.go.jp/nbrc/catalogue/' \
              'NBRCCatalogueDetailServlet?ID=IFO&CAT=',
        NCTC: 'https://www.culturecollections.org.uk/products/bacteria/' \
              'detail.jsp?collection=nctc&refId=NCTC+',
        CIP:  'https://catalogue-crbip.pasteur.fr/' \
              'fiche_catalogue.xhtml?crbip=CIP%20',
        PCC:  'https://catalogue-crbip.pasteur.fr/' \
              'fiche_catalogue.xhtml?crbip=PCC%20',
        CCUG: 'https://www.ccug.se/strain?id=',
        NRRL: 'https://nrrl.ncaur.usda.gov/cgi-bin/usda/prokaryote/' \
              'report.html?nrrlcodes='
      }
      o = sanitize(name.type_text)
      collections.each do |k, v|
        o = o.gsub(
          /(?<=Strain: | = )(#{k})[ -]([\d\-A-Za-z]+)(?= = |$)/,
          "<a href='#{v}\\2' target='_blank'>\\1 \\2 #{ext}</a>"
        )
      end
      o.html_safe
    else
      name.type_text
    end
  end

  def link_to_name(name)
    link_to(name.name_html, name)
  end

  def name_lineage(name, links: true, last: true, register: nil, visited: [])
    assume_valid = register&.names&.include?(name)
    out = []
    visited << name

    # Recursively get the parent(s)
    if name.incertae_sedis?
      out << content_tag(:span, name.incertae_sedis_html)
      out << content_tag(:span, ' &raquo; '.html_safe)
    elsif name.parent
      if visited.include? name.parent
        out << content_tag(:span, 'Recursion found: ' , class: 'text-danger')
      else
        out << name_lineage(
          name.parent,
          links: links, last: false, register: register, visited: visited
        )
        out << content_tag(:span, ' &raquo; '.html_safe)
      end
    end

    # Display the current name
    if links && !last
      out << link_to(name.name_html(nil, assume_valid), name)
    else
      out << name.name_html(nil, assume_valid)
    end

    out.inject(:+)
  end
end
