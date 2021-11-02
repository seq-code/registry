class AddRegisterToNames < ActiveRecord::Migration[6.1]
  def change
    add_reference :names, :register, null: true, foreign_key: true
  end
end
