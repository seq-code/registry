class AddDataciteJsonToPublications < ActiveRecord::Migration[6.1]
  def change
    add_column :publications, :datacite_json, :string, default: nil
  end
end
