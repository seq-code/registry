module NamesHelper
  def strain_html(name, opts = {})
    opts[:ext] = true if opts[:ext].nil?
    ext = opts[:ext] ? '<sup class="fas fa-external-link-alt "> </sup>' : ''
    parsed = name.type_is_strain? ? :type_strain_parsed : :genome_strain_parsed
    name.send(parsed).map do |str|
      if str.is_a? Hash
        '<a href="%s" target="_blank">%s %s</a>' % [
          str[:url], sanitize(str[:accession]), ext
        ]
      else
        str
      end
    end.join(' = ').html_safe
  end

  def link_to_name_type(name)
    if name.type_is_name?
      if name.type_name
        link_to(name.type_name) { name.type_name.name_html } +
        if place = name.type_name_alt_placement
          content_tag(:span, ' (alternatively placed in ') +
            display_link(place) +
            content_tag(:span, ')')
        end
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
      content_tag(:span, 'Strain: ') + strain_html(name)
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
