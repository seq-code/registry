class RenamePlacementIncertaeSedisToLegacy < ActiveRecord::Migration[6.1]
  def up
    rename_column :placements, :incertae_sedis, :incertae_sedis_legacy
    add_column :placements, :incertae_sedis, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE placements
      SET incertae_sedis = TRUE
      WHERE LOWER(TRIM(incertae_sedis_legacy::text)) NOT IN ('', 'false', 'f', '0')
    SQL

    %w[Bacteria Archaea].each do |domain|
      execute <<~SQL
        UPDATE placements
        SET parent_id = (SELECT id FROM names WHERE name = '#{domain}' LIMIT 1)
        WHERE LOWER(TRIM(incertae_sedis_legacy::text)) =
          'incertae sedis (#{domain.downcase})'
      SQL
    end
  end

  def down
    remove_column :placements, :incertae_sedis
    rename_column :placements, :incertae_sedis_legacy, :incertae_sedis
  end
end
