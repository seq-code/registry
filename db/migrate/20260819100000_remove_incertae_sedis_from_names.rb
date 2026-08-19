# frozen_string_literal: true

# Removes the legacy incertae sedis attributes now represented by placements.
class RemoveIncertaeSedisFromNames < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
      DELETE FROM action_text_rich_texts
      WHERE record_type = 'Name'
        AND name = 'incertae_sedis_text'
    SQL

    remove_column :names, :incertae_sedis, :string if column_exists?(:names, :incertae_sedis)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
