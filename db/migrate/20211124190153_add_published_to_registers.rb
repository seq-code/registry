class AddPublishedToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :published, :boolean
    add_column :registers, :published_at, :datetime
    add_column :registers, :published_doi, :string
    add_column :registers, :published_by, :integer
  end
end
