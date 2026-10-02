module NamesHelper
  def history_values(changes, attribute:)
    values =
      case attribute
      when 'etymology'
        history_diff_parts(*changes.map { |attributes| Name.new(attributes).full_etymology })
      when 'proposed_in_id'
        changes.map { |id| history_publication_reference(id) }
      when 'status'
        changes.map { |code| Name.status_hash.dig(code, :name) || code }
      else
        changes.any? { |value| value.is_a?(String) } ? history_diff_parts(*changes) : changes
      end

    values.map { |value| safe_join(Array(value)).presence || '—' }
  end

  def history_publication_reference(publication_id)
    publication = Publication.find_by(id: publication_id) if publication_id
    if publication
      link_to(publication.short_citation, publication)
    elsif publication_id
      "Publication ##{publication_id} (deleted)"
    end
  end

  def history_diff_parts(before, after)
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
