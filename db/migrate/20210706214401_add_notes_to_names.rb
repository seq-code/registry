class AddNotesToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :notes, :text
  end
end
