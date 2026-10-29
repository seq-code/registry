module Names::HistoriesHelper
  # Render a recorded [before, after] pair as two display values.
  def history_values(changes, attribute:, record_type: 'Name')
    # Some name attributes need domain-specific formatting; everything else,
    # on any record type, is rendered generically from its model.
    values = history_name_values(changes, attribute) if record_type == 'Name'
    values ||= history_attribute_values(record_type.constantize, changes, attribute)
    
    # Diffs return arrays of parts; empty values show as a dash.
    values.map { |value| safe_join(Array(value)).presence || '—' }
  end

  # Rich text changes are shown as changes of the name itself.
  def history_record_type(version)
    version.record_type == 'ActionText::RichText' ? 'Name' : version.record_type
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

  # Label a link's changes with what it links to.
  def history_record_heading(version)
    return history_link_reference(version.record) if version.record

    # The link itself was deleted, e.g. along with its publication.
    "#{version.record_type.constantize.model_name.human} (deleted)"
  end

  # Publication links identify their publication. Placement headings stay neutral
  # because a retained placement's current parent may differ from earlier edits.
  def history_link_reference(record)
    case record
    when PublicationName
      safe_join(['Publication: ', link_to(record.display, record.publication)])
    when Placement
      'Placement'
    end
  end

  def history_text_diff(before, after)
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

  # Diff rich text HTML, rendering each side as formatted text with its changes
  # marked. The HTML is sanitized as ActionText content is, plus ins and del.
  def history_html_diff(before, after)
    HtmlDiff.diff(before, after).map do |html|
      sanitize(
        html,
        tags: ActionText::ContentHelper.allowed_tags + %w[ins del],
        attributes: ActionText::ContentHelper.allowed_attributes
      )
    end
  end

  private

  # Name attributes that need domain-specific rendering, or nil for the rest.
  def history_name_values(changes, attribute)
    case attribute
    when 'description', 'etymology_text'
      history_html_diff(*changes)
    when 'etymology'
      history_text_diff(*changes.map { |attributes| Name.new(attributes).full_etymology })
    when 'corrigendum_kind'
      changes.map { |kind| Name.corrigendum_kinds.dig(kind&.to_sym, :name) || kind }
    when 'status'
      changes.map { |code| Name.status_hash.dig(code, :name) || code }
    end
  end

  # Link foreign keys to their records, diff text, and show booleans as Yes/No.
  # Ordinary associations are matched by their actual foreign key, which need
  # not follow the association's name. Polymorphic references arrive grouped
  # under the association's name as [type, id] pairs.
  def history_attribute_values(model, changes, attribute)
    association = model.reflect_on_all_associations(:belongs_to).find do |reflection|
      attribute == (reflection.polymorphic? ? reflection.name.to_s : reflection.foreign_key)
    end
    if association&.polymorphic?
      changes.map { |type, id| history_polymorphic_reference(type, id) }
    elsif association
      changes.map { |id| history_record_reference(association.klass, id) }
    elsif changes.any? { |value| value.is_a?(String) }
      history_text_diff(*changes)
    else
      changes.map { |value| { true => 'Yes', false => 'No' }.fetch(value, value) }
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
end
