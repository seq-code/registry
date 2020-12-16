class AddEmendsToPublicationName < ActiveRecord::Migration[6.0]
  def change
    add_column :publication_names, :emends, :boolean, default: false
  end
end
