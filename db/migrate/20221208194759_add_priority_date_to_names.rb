class AddPriorityDateToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :priority_date, :datetime, default: nil
  end
end
