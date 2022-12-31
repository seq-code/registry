class AddAutoFailedToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_column :genomes, :auto_failed, :text, default: nil
  end
end
