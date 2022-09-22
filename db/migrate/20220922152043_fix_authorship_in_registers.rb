class FixAuthorshipInRegisters < ActiveRecord::Migration[6.1]
  def change
    change_column(:registers, :submitter_is_author, :boolean)
    change_column(:registers, :authors_approval, :boolean)
  end
end
