module Names::HistoriesHelper
  include DiffHelper

  # Render a recorded [before, after] pair as two display values.
  def history_values(changes, attribute:, record_type: 'Name')
    values =
      case [record_type, attribute]
      when ['Name', 'description'], ['Name', 'etymology_text']
        html_diff(*changes)
      when ['Name', 'etymology']
        text_diff(*changes.map { |attributes| Name.new(attributes).full_etymology })
      when ['Name', 'corrigendum_kind']
        changes.map { |kind| Name.corrigendum_kinds.dig(kind&.to_sym, :name) || kind }
      when ['Name', 'status']
        changes.map { |code| Name.status_hash.dig(code, :name) || code }
      else
        history_attribute_values(record_type.constantize, changes, attribute)
      end

    values.map { |value| ERB::Util.html_escape(value).presence || '—' }
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

  # Label a link's changes with what it links to. Publication links identify
  # their publication and paratypes their strain, even once deleted. Placement
  # headings stay neutral because a placement's current parent may differ from
  # earlier edits.
  def history_record_heading(version)
    case version.record_type
    when 'Placement'
      'Placement'
    when 'PublicationName'
      publication_id = version.changeset['publication_id'].compact.first
      safe_join(['Publication: ', history_record_reference(Publication, publication_id)])
    when 'NameParatype'
      strain_id = version.changeset['nomenclatural_type_id'].compact.first
      safe_join(['Paratype: ', history_paratype_reference(strain_id)])
    else
      raise ArgumentError, "Unsupported history record heading: #{version.record_type}"
    end
  end

  private

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
      text_diff(*changes)
    else
      changes.map { |value| { true => 'Yes', false => 'No' }.fetch(value, value) }
    end
  end

  # Paratypes are always strains, linked by their title as on the name page.
  def history_paratype_reference(strain_id)
    strain = Strain.find_by(id: strain_id)
    strain ? link_to(strain.title(sup: false), strain) : "Strain ##{strain_id} (deleted)"
  end

  def history_polymorphic_reference(type, id)
    # Resolve only model classes, not any constant a recorded type string names.
    record_class = type&.safe_constantize
    if record_class.is_a?(Class) && record_class < ApplicationRecord
      history_record_reference(record_class, id)
    elsif id
      "#{type} ##{id}"
    end
  end
end
