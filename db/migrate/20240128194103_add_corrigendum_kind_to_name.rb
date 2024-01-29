class AddCorrigendumKindToName < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :corrigendum_kind, :text, default: nil
  end
end
