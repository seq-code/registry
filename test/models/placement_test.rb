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

  test 'incertae sedis placement can have no parent' do
    placement = Placement.new(
      name: names(:escherichia), incertae_sedis: true,
      incertae_sedis_text: 'Its placement is unresolved.'
    )

    assert_predicate placement, :valid?
  end

  test 'incertae sedis HTML includes its parent' do
    placement = Placement.new(
      name: names(:escherichia), parent: names(:bacteria), incertae_sedis: true
    )

    assert_equal(
      '<i>incertae sedis</i> (Bacteria)', placement.incertae_sedis_html
    )
  end

  test 'incertae sedis HTML without a parent omits the qualifier' do
    placement = Placement.new(
      name: names(:escherichia), incertae_sedis: true
    )

    assert_equal '<i>incertae sedis</i>', placement.incertae_sedis_html
  end
end
