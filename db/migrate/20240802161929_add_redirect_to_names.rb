class AddRedirectToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :redirect_id, :integer, default: nil
  end
end
