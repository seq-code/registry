class AddUniqueObserversIndex < ActiveRecord::Migration[6.1]
  def change
    add_index :observe_names, [:user_id, :name_id], name: 'observe_names_uniqueness', unique: true
    add_index :observe_registers, [:user_id, :register_id], name: 'observe_registers_uniqueness', unique: true
  end
end
