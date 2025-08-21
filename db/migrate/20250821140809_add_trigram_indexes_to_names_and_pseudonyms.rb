class AddTrigramIndexesToNamesAndPseudonyms < ActiveRecord::Migration[6.1]
  def up
    # Only apply if using PostgreSQL
    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      # Enable extensions
      execute 'CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;'
      execute 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'

      # Add trigram index to names.name
      execute <<-SQL
        CREATE INDEX index_names_on_name_trgm ON names
        USING gin (name gin_trgm_ops);
      SQL
      # Add trigram index to pseudonyms.pseudonym
      execute <<-SQL
        CREATE INDEX index_pseudonyms_on_pseudonym_trgm ON pseudonyms
        USING gin (pseudonym gin_trgm_ops);
      SQL
    end
  end

  def down
    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      execute 'DROP INDEX IF EXISTS index_names_on_name_trgm;'
      execute 'DROP INDEX IF EXISTS index_pseudonyms_on_pseudonym_trgm;'
      # Safer to keep them, no need to remove them
      # execute 'DROP EXTENSION IF EXISTS fuzzystrmatch;'
      # execute 'DROP EXTENSION IF EXISTS pg_trgm;'
    end
  end
end

