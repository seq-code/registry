class AddIncertaeSedisToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :incertae_sedis, :string, default: nil
  end
end
