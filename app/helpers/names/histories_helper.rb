module Names::HistoriesHelper
  include DiffHelper

  HISTORY_OPERATIONS = { 'create' => 'added', 'update' => 'changed', 'delete' => 'removed' }.freeze

  # Rows to render for a version's changes, each [label, before, after].
  # Changes to records linked to the name start with a [heading] row, e.g.
  # ['Placement added'].
  def history_rows(version, changes)
    if version.record_type == 'ActionText::RichText'
      label = Name.human_attribute_name(version.changeset['name'].compact.first)
      return [[label, *history_display(html_diff(*changes['body']))]]
    end

    model = version.record_type.constantize
    rows = changes.map do |attribute, values|
      [model.human_attribute_name(attribute), *history_display(history_values(model, attribute, values))]
    end
    return rows if model == Name

    [["#{model.model_name.human} #{HISTORY_OPERATIONS.fetch(version.operation)}"], *rows]
  end

  private

  # Link records, diff text, and show booleans as Yes/No.
  def history_values(model, attribute, values)
    association = model.reflect_on_association(attribute.delete_suffix('_id'))
    name_values = history_name_values(attribute, values) if model == Name
    if name_values
      name_values
    elsif association&.polymorphic?
      values.map { |type, id| history_record_link(type, id) }
    elsif association&.belongs_to?
      values.map { |id| history_record_link(association.class_name, id) }
    elsif values.any?(String)
      text_diff(*values)
    else
      values.map { |value| { true => 'Yes', false => 'No' }.fetch(value, value) }
    end
  end

  # Name attributes recorded in a form that needs translating to be read.
  def history_name_values(attribute, values)
    case attribute
    when 'etymology'
      text_diff(*values.map { |attributes| Name.new(attributes).full_etymology })
    when 'status'
      values.map { |code| Name.status_hash.dig(code, :name) || code }
    when 'corrigendum_kind'
      values.map { |kind| Name.corrigendum_kinds.dig(kind&.to_sym, :name) || kind }
    end
  end

  def history_record_link(type, id)
    return unless id

    # Resolve only model classes, not any constant a recorded type names.
    record_class = type.safe_constantize
    record = record_class.find_by(id: id) if record_class.is_a?(Class) && record_class < ApplicationRecord
    return "#{type} ##{id} (deleted)" unless record

    # Some records, such as generic type material, have no page of their own.
    link_to_if(respond_to?("#{record.model_name.singular_route_key}_path"), record.display, record)
  end

  def history_display(values)
    values.map { |value| ERB::Util.html_escape(value).presence || '—' }
  end
end
