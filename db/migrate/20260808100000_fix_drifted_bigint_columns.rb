class FixDriftedBigintColumns < ActiveRecord::Migration[6.1]
  # These columns were all added via `t.references`/`add_reference` under
  # ActiveRecord::Migration[6.1] or later, which defaults to :bigint, but
  # this database has carried them as :integer since before that default
  # was consistently applied here. This brings them back in line with what
  # a fresh `db:schema:load` (and the migrations that created them) intend,
  # so they stop showing up as unrelated noise in every future schema dump.
  def change
    change_column :action_text_rich_texts, :record_id, :bigint
    change_column :active_storage_attachments, :record_id, :bigint
    change_column :active_storage_attachments, :blob_id, :bigint
    change_column :active_storage_blobs, :byte_size, :bigint
    change_column :name_correspondences, :name_id, :bigint
    change_column :name_correspondences, :user_id, :bigint
    change_column :names, :register_id, :bigint
    change_column :names, :tutorial_id, :bigint
    change_column :names, :genome_id, :bigint
    change_column :registers, :user_id, :bigint
    change_column :registers, :publication_id, :bigint
    change_column :tutorials, :user_id, :bigint
  end
end
