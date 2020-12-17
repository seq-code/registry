class AddSyllabicationToNames < ActiveRecord::Migration[6.0]
  def change
    add_column :names, :syllabication, :string
    add_column :names, :syllabication_reviewed, :boolean
  end
end
