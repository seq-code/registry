class AddItisToName < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :itis_json, :text, default: nil
    add_column :names, :itis_at, :datetime, default: nil
  end
end
