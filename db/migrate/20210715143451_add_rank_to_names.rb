class AddRankToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :rank, :string, default: nil
  end
end
