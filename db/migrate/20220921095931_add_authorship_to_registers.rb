class AddAuthorshipToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :submitter_is_author, :bool
    add_column :registers, :authors_approval, :bool
  end
end
