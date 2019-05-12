class AddAbstractToPublications < ActiveRecord::Migration[5.1]
  def change
    add_column :publications, :abstract, :string
  end
end
