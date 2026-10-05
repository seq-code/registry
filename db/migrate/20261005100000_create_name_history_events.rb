class CreateNameHistoryEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :name_history_events do |t|
      t.references :name, null: false, index: false
      t.string :kind, null: false
      t.jsonb :data, null: false
      t.datetime :created_at, null: false

      t.index %i[name_id created_at id]
    end

    reversible do |direction|
      direction.up do
        # Keep the public history already recorded by name-history. Use the
        # migration's schema rather than application models for this snapshot.
        attributes = %w[
          name rank syllabication status priority_date authority
          nomenclatural_status taxonomic_status proposal_kind corrigendum_from
          type_material type_accession proposed_in_id
        ]
        attributes.concat(connection.columns(:names).map(&:name).grep(/\Aetymology_/))
        keys = attributes.map { |attribute| connection.quote(attribute) }.join(', ')

        execute <<~SQL
          INSERT INTO name_history_events (name_id, kind, data, created_at)
          SELECT versions.record_id, 'attributes_changed', public_changes.data, versions.created_at
          FROM versions
          CROSS JOIN LATERAL (
            SELECT jsonb_object_agg(key, value) AS data
            FROM jsonb_each(versions.changeset)
            WHERE key IN (#{keys})
          ) AS public_changes
          WHERE versions.record_type = 'Name'
            AND versions.operation = 'update'
            AND public_changes.data IS NOT NULL
          ORDER BY versions.created_at, versions.id
        SQL
      end
    end
  end
end
