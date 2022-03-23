class AddDataToTutorials < ActiveRecord::Migration[6.1]
  def change
    add_column :tutorials, :data, :text, default: nil
  end
end
