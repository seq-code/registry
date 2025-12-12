class AddBasonymToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :basonym_id, :integer, default: nil
  end
end
