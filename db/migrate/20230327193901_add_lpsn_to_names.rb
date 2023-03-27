class AddLpsnToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :proposal_kind, :string, default: nil
    add_column :names, :nomenclatural_status, :string, default: nil
    add_column :names, :taxonomic_status, :string, default: nil
    add_column :names, :authority, :string, default: nil
    add_column :names, :lpsn_url, :string, default: nil
    add_column :names, :correct_name_id, :integer, default: nil
  end
end
