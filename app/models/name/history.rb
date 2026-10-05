module Name::History
  extend ActiveSupport::Concern

  ETYMOLOGY_ATTRIBUTES = Name.column_names.grep(/\Aetymology_/).freeze
  ATTRIBUTES = %w[
    name rank syllabication status priority_date authority
    nomenclatural_status taxonomic_status proposal_kind corrigendum_from
    type_material type_accession proposed_in_id
  ].concat(ETYMOLOGY_ATTRIBUTES).freeze

  included do
    has_many :history_events, class_name: 'NameHistoryEvent'
    after_update :record_attribute_history
  end

  private

  def record_attribute_history
    changes = saved_changes.slice(*ATTRIBUTES)
    return if changes.empty?

    # Etymology is rendered as a whole, with the final particle derived from
    # the name. Retain its context so later edits cannot change old history.
    etymology_context = ['name', *ETYMOLOGY_ATTRIBUTES]
    if (changes.keys & etymology_context).any?
      etymology_context.each do |attribute|
        values = [attribute_before_last_save(attribute), self[attribute]]
        changes[attribute] = values unless values == [nil, nil]
      end
    end

    history_events.create!(kind: 'attributes_changed', data: changes)
  end
end
