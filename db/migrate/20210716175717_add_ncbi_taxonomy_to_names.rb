class AddNcbiTaxonomyToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :ncbi_taxonomy, :integer, default: nil
  end
end
