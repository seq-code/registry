class AddStrainToGenomes < ActiveRecord::Migration[6.1]
  def change
    add_reference :genomes, :strain, null: true, foreign_key: true
  end
end
