class RemoveExplicitBasisPatternFromTags < ActiveRecord::Migration[6.1]
  def change
    remove_column :tags, :explicit_basis_pattern, :text
  end
end
