class RemoveDoiFromRegister < ActiveRecord::Migration[6.1]
  def change
    remove_column :registers, :doi, :string
  end
end
