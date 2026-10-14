# frozen_string_literal: true

require 'application_system_test_case'

class PlacementsTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    @user = users(:curator)
    @parent = names(:escherichia)

    login_as(@user, scope: :user)
  end

  teardown { Warden.test_reset! }

  test 'creating the first placement for a name' do
    name = Name.create!(
      name: 'Escherichia vulneris', rank: 'species', status: 5,
      created_by: @user
    )

    assert_nil(name.placement)

    visit new_placement_path(name)
    choose 'Fixed placement'
    fill_in 'Parent genus', with: @parent.name
    click_button 'Submit'

    assert_text 'Placement successfully updated'
    assert_current_path name_path(name)

    name.reload

    assert_equal(@parent, name.placement.parent)
    assert_predicate(name.placement, :preferred?)
  end

  test 'declaring incertae sedis in Bacteria' do
    name = Name.create!(
      name: 'Escherichia ruysiae', rank: 'species', status: 5,
      created_by: @user
    )
    explanation = 'Its placement within Bacteria is unresolved.'

    visit new_placement_path(name)
    choose 'Incertae sedis'
    fill_in 'Uncertain within', with: names(:bacteria).name
    fill_in_rich_text_area(
      'Description of the classification problems', with: explanation
    )
    click_button 'Submit'

    assert_text 'Placement successfully updated'
    assert_current_path name_path(name)

    name.reload
    placement = name.placement

    assert_predicate placement, :incertae_sedis?
    assert_equal names(:bacteria), placement.parent
    assert_equal(explanation, placement.incertae_sedis_text.to_plain_text)
    assert_nil name.parent
    assert_predicate(placement, :preferred?)
  end

  test 'adding a second non-preferred placement' do
    name = names(:escherichia_coli)
    alternative_parent = Name.create!(
      name: 'Shigella', rank: 'genus', status: 15
    )

    visit name_path(name)
    click_link 'Report alternative placement'
    choose 'Fixed placement'
    fill_in 'Parent genus', with: alternative_parent.name
    click_button 'Submit'

    assert_text 'Placement successfully updated'
    assert_current_path name_path(name)

    name.reload
    alternative_placements = name.alt_placements

    assert_equal(@parent, name.placement.parent)
    assert_equal([alternative_parent], alternative_placements.map(&:parent))
    assert_not_predicate(alternative_placements.first, :preferred?)
  end

end
