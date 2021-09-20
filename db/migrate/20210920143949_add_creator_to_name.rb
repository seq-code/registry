class AddCreatorToName < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :created_by, :integer, default: nil
  end
end
