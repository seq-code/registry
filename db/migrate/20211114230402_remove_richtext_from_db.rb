class RemoveRichtextFromDb < ActiveRecord::Migration[6.1]
  def change
    remove_column :name_correspondences, :message, :text
    remove_column :names, :description, :text
    remove_column :names, :notes, :text
    remove_column :names, :etymology_text, :text
    remove_column :registers, :notes, :text
    remove_column :registers, :abstract, :text
  end
end
