class RemoveTypeFromPublications < ActiveRecord::Migration[5.1]
  def change
    remove_column :publications, :type, :string
  end
end
