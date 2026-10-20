module NamesHelper
  def link_to_name_type(name)
    if name.type_is_name?
      if name.type_name
        display_link(name.type_name, :name_html_correctness) +
        if rep = name.type_name_alt_placement
          content_tag(:span, ' (alternatively placed in ') +
            display_link(rep) +
            content_tag(:span, ')')
        elsif rep = name.type_name.correct_name
          content_tag(:span, ' (correct name: ') +
            display_link(rep) +
            content_tag(:span, ')')
        end
      else
        content_tag(
          :span, "Illegal name: #{name.nomenclatural_type_id}",
          class: 'text-danger'
        )
      end
    elsif name.type_genome
      link_to(name.type_genome.title, name.type_genome)
    elsif name.type_is_strain?
      strain_html(name)
    else
      name.type_text
    end
  end

  def link_to_name(name)
    link_to(name.name_html, name)
  end

  def name_lineage(name, links: true, last: true, register: nil, visited: [])
    return content_tag(:span, '') if name.nil?

    assume_valid = register&.names&.include?(name)
    out = []
    visited << name

    if visited.include? name.placement&.parent
      # Break circular recursions
      out << content_tag(:span, 'Recursion found: ', class: 'text-danger')
    else
      # Recursively get the parent(s)
      out << name_lineage(
        name.placement&.parent,
        links: links, last: false, register: register, visited: visited
      )

      # Indicate if a placement is uncertain
      if name.incertae_sedis?
        out << content_tag(
          :em, 'incertae sedis', class: 'text-secondary',
          title: name.incertae_sedis_text.to_plain_text
        )
        out << content_tag(:span, ' &raquo; '.html_safe)
      end
    end

    # Display the current name
    if links && !last
      out << display_link(
        name, :name_html,
        display_text: name.name_html(assume_valid: assume_valid),
        title: name.rank
      )
    else
      out << name.name_html(assume_valid: assume_valid)
    end
    out << content_tag(:span, ' &raquo; '.html_safe) unless last

    out.inject(:+)
  end
end
