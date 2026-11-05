class AddExplicitBasisPatternToTags < ActiveRecord::Migration[6.1]
  def change
    # Optional regular expression the basis of a proposal must match for the
    # tag to be proposed at high confidence (e.g., an explicit "masc." for
    # masculine); proposals that don't match are capped at medium
    add_column :tags, :explicit_basis_pattern, :text
  end
end
