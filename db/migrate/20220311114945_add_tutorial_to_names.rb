class AddTutorialToNames < ActiveRecord::Migration[6.1]
  def change
    add_reference :names, :tutorial, null: true, foreign_key: true, default: nil
  end
end
