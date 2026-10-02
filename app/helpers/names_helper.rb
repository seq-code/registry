module NamesHelper
  def history_before_value(changes, attribute:)
    before = changes.first
    if attribute == 'etymology'
      before = history_etymology_parts(*changes).first
    end

    safe_join(Array(before)).presence || '—'
  end

  def history_after_value(changes, attribute:)
    after = changes.last
    if attribute == 'etymology'
      after = history_etymology_parts(*changes).last
    end

    safe_join(Array(after)).presence || '—'
  end

  def history_etymology_parts(before, after)
    before = Name.new(before).full_etymology
    after = Name.new(after).full_etymology

    chunks = TextDiff.chunks(before, after)

    before_parts = chunks.filter_map do |unchanged, text, _|
      next if text.empty?

      unchanged ? text : content_tag(:del, text, class: 'text-danger')
    end
    after_parts = chunks.filter_map do |unchanged, _, text|
      next if text.empty?

      unchanged ? text : content_tag(:ins, text, class: 'text-success')
    end

    [before_parts, after_parts]
  end

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
      out << display_link(
        name, :name_html,
        display_text: name.name_html(assume_valid: assume_valid)
      )
    else
      out << name.name_html(assume_valid: assume_valid)
    end

    out.inject(:+)
  end

  private

end
