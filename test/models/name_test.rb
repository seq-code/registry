require 'test_helper'

class NameTest < ActiveSupport::TestCase
  test 'lineage follows the parent for a normally placed species' do
    name = names(:escherichia_coli)

    assert_equal names(:escherichia), name.lineage_parent
    assert_equal [names(:escherichia), name], name.lineage(with_self: true)
  end

  test 'incertae sedis lineage follows the preferred placement parent' do
    name = names(:escherichia_coli)
    name.parent = nil
    name.placement.incertae_sedis = true
    name.placement.parent = names(:bacteria)

    assert_equal names(:bacteria), name.lineage_parent
    assert_equal [names(:bacteria), name], name.lineage(with_self: true)
  end

  test 'lineage without a parent or preferred placement contains only itself' do
    name = Name.new(name: 'Escherichia coli', rank: 'species')

    assert_nil name.lineage_parent
    assert_equal [name], name.lineage(with_self: true)
  end

  test 'ranks at or above returns ranks from domain through the given rank' do
    assert_equal %w[domain phylum class], Name.ranks_at_or_above('class')
  end

  test 'ranks at or above returns nil for an unknown rank' do
    assert_nil Name.ranks_at_or_above('strain')
  end

  test 'add_to_register adds name to a draft register' do
    name = names(:unregistered)
    register = registers(:draft)

    assert register.draft?
    assert name.add_to_register(register, users(:contributor))
    assert_equal register, name.reload.register
  end

  test 'add_to_register refuses non-draft registers' do
    name = names(:unregistered)
    register = registers(:submitted)

    assert_not register.draft?
    assert_not name.add_to_register(register, users(:contributor))
    assert_includes name.errors[:register], 'must be a draft'
    assert_nil name.reload.register
  end

  test 'incertae sedis HTML comes from the preferred placement' do
    name = names(:incertae_sedis)

    assert_equal(
      '<i>incertae sedis</i> (Bacteria)', name.incertae_sedis_html
    )
  end
end
