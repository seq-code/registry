class AddReviewerTokenToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :reviewer_token, :string, default: nil
  end
end
