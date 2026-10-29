class GeneralizeRelationshipSoftDeletion < ActiveRecord::Migration[6.1]
  def up
    rename_column :publication_names, :unlinked_at, :deleted_at
    rename_column :placements, :unlinked_at, :deleted_at
    rename_history_key('unlinked_at', 'deleted_at')
  end

  def down
    rename_history_key('deleted_at', 'unlinked_at')
    rename_column :placements, :deleted_at, :unlinked_at
    rename_column :publication_names, :deleted_at, :unlinked_at
  end

  private

  def rename_history_key(before, after)
    execute <<~SQL
      UPDATE versions
      SET changeset = (changeset - #{quote(before)}) ||
        jsonb_build_object(#{quote(after)}, changeset -> #{quote(before)})
      WHERE record_type IN ('PublicationName', 'Placement')
        AND changeset ? #{quote(before)}
    SQL
  end
end
