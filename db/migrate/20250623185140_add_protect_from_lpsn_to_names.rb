class AddProtectFromLpsnToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :protect_from_lpsn, :string, default: nil
  end
end
