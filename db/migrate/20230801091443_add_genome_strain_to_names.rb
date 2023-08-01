class AddGenomeStrainToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :genome_strain, :string, default: nil
  end
end
