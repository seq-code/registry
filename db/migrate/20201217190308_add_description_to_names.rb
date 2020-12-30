class AddDescriptionToNames < ActiveRecord::Migration[6.0]
  def change
    add_column :names, :description, :text
  end
end
