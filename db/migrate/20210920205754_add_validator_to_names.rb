class AddValidatorToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :validated_by, :integer, default: nil
    add_column :names, :validated_at, :datetime, default: nil
  end
end
