module NamesHelper
  def history_values(changes, attribute:, record_type: 'Name')
    values =
      case record_type
      when 'PublicationName'
        history_publication_name_values(changes)
      when 'Name'
        history_name_values(changes, attribute)
      else
        raise ArgumentError, "Unsupported public history record type: #{record_type}"
      end

    values.map { |value| safe_join(Array(value)).presence || '—' }
  end

  def history_record_reference(record_class, id)
    return unless id

    record = record_class.find_by(id: id)
    if record.nil?
      "#{record_class.name} ##{id} (deleted)"
    elsif record.is_a?(GenericTypeMaterial)
      # Generic type material has no dedicated page to link to.
      record.display
    else
      link_to(record.display, record)
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

  private

  def history_name_values(changes, attribute)
    # Grouped values and status codes need domain-specific rendering before
    # ordinary foreign keys can be resolved through their associations.
    case attribute
    when 'etymology'
      history_diff_parts(*changes.map { |attributes| Name.new(attributes).full_etymology })
    when 'genome_id'
      # This legacy column has a custom reader, but no belongs_to association.
      changes.map { |id| history_record_reference(Genome, id) }
    when 'corrigendum_kind'
      changes.map { |kind| Name.corrigendum_kinds.dig(kind&.to_sym, :name) || kind }
    when 'status'
      changes.map { |code| Name.status_hash.dig(code, :name) || code }
    else
      history_association_values(changes, attribute)
    end
  end

  # Match ordinary associations by their actual foreign key, which need not
  # follow the association's name. Polymorphic references arrive grouped under
  # the association's name as [type, id] pairs.
  def history_association_values(changes, attribute)
    association = Name.reflect_on_all_associations(:belongs_to).find do |reflection|
      attribute == (reflection.polymorphic? ? reflection.name.to_s : reflection.foreign_key)
    end
    if association.nil?
      history_text_values(changes)
    elsif association.polymorphic?
      changes.map { |type, id| history_polymorphic_reference(type, id) }
    else
      changes.map { |id| history_record_reference(association.klass, id) }
    end
  end

  def history_polymorphic_reference(type, id)
    # Resolve only model classes, not any constant a recorded type string names.
    record_class = type&.safe_constantize
    if record_class.is_a?(Class) && record_class < ApplicationRecord
      history_record_reference(record_class, id)
    elsif id
      # Older versions may have recorded an ID without its unchanged type.
      "#{type || 'Unknown type'} ##{id}"
    else
      type
    end
  end

  def history_publication_name_values(changes)
    history_text_values(changes).map do |value|
      case value
      when true then 'Yes'
      when false then 'No'
      else value
      end
    end
  end

  def history_text_values(changes)
    changes.any? { |value| value.is_a?(String) } ? history_diff_parts(*changes) : changes
  end
end
