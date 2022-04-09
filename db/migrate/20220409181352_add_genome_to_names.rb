class AddGenomeToNames < ActiveRecord::Migration[6.1]
  def change
    add_reference :names, :genome, null: true, foreign_key: true
  end
end
