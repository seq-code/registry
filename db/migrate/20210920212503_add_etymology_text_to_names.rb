class AddEtymologyTextToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :etymology_text, :text
  end
end
