class AddStatusToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :status, :integer, default: 0
  end
end
