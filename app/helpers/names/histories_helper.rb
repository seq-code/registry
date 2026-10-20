module Names::HistoriesHelper
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
