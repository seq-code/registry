class AddSubmittedToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :submitted_by, :integer
    add_column :names, :submitted_at, :datetime
  end
end
