class AddSourceJsonToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :source_json, :text, default: nil
  end
end
