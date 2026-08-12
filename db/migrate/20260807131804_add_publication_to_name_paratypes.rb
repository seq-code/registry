class AddPublicationToNameParatypes < ActiveRecord::Migration[6.1]
  def change
    add_reference :name_paratypes, :publication, null: false, foreign_key: true
  end
end
