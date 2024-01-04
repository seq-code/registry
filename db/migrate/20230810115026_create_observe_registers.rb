class CreateObserveRegisters < ActiveRecord::Migration[6.1]
  def change
    create_table :observe_registers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :register, null: false, foreign_key: true

      t.timestamps
    end
  end
end
