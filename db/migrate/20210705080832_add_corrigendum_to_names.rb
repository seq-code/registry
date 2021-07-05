class AddCorrigendumToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :corrigendum_by, :integer, default: nil
    add_column :names, :corrigendum_from, :string, default: nil
  end
end
