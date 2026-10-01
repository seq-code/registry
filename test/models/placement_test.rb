require 'test_helper'

class PlacementTest < ActiveSupport::TestCase
  test 'placement has a parent' do
    placement = Placement.new(
      name: names(:escherichia_coli), parent: names(:escherichia),
      incertae_sedis: false
    )

    assert_predicate placement, :valid?
  end

  test 'incertae sedis placement can have a parent' do
    placement = Placement.new(
      name: names(:escherichia), parent: names(:bacteria), incertae_sedis: true,
      incertae_sedis_text: 'Its placement within Bacteria is unresolved.'
    )

    assert_predicate placement, :valid?
  end

  test 'fixed placement allows only the immediate parent rank' do
    placement = Placement.new(name: names(:escherichia_coli), incertae_sedis: false)

    assert_equal ['genus'], placement.allowed_parent_ranks
  end

  test 'incertae sedis allows all ranks at least two above the name' do
    placement = Placement.new(name: names(:escherichia_coli), incertae_sedis: true)

    assert_equal %w[domain phylum class order family], placement.allowed_parent_ranks
    assert_equal ['genus'], placement.allowed_parent_ranks(incertae_sedis: false)
  end

  test 'placement allows no parent ranks without higher ranks or a name' do
    [names(:bacteria), nil].each do |name|
      placement = Placement.new(name: name)

      assert_empty placement.allowed_parent_ranks(incertae_sedis: false)
      assert_empty placement.allowed_parent_ranks(incertae_sedis: true)
    end
  end

  test 'phylum allows a fixed domain parent but no incertae sedis parent' do
    placement = Placement.new(name: Name.new(name: 'Bacillota', rank: 'phylum'))

    assert_equal ['domain'], placement.allowed_parent_ranks(incertae_sedis: false)
    assert_empty placement.allowed_parent_ranks(incertae_sedis: true)
  end

  test 'preferred incertae sedis parent is not synced to the name' do
    name = names(:escherichia)
    placement = Placement.create!(
      name: name, parent: names(:bacteria), incertae_sedis: true,
      incertae_sedis_text: 'Its placement within Bacteria is unresolved.',
      preferred: true
    )

    assert_equal names(:bacteria), placement.parent
    assert_nil name.reload.parent
  end

  test 'incertae sedis placement must have a parent' do
    placement = Placement.new(
      name: names(:escherichia), incertae_sedis: true,
      incertae_sedis_text: 'Its placement is unresolved.'
    )

    assert_not_predicate placement, :valid?
    assert_includes placement.errors[:parent], "can't be blank"
  end

  test 'incertae sedis HTML includes its parent' do
    placement = Placement.new(
      name: names(:escherichia), parent: names(:bacteria), incertae_sedis: true
    )

    assert_equal(
      '<i>incertae sedis</i> (Bacteria)', placement.incertae_sedis_html
    )
  end

end
