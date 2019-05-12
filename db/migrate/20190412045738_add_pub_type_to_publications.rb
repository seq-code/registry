class AddPubTypeToPublications < ActiveRecord::Migration[5.1]
  def change
    add_column :publications, :pub_type, :string
  end
end
