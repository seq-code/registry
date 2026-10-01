require 'test_helper'

class PlacementsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @curator = users(:curator)
    @name = names(:draft_by_contributor)
    sign_in(@curator)
  end

  test 'creates a preferred incertae sedis placement' do
    assert_difference('Placement.count', 1) do
      post placements_url, params: {
        placement: {
          name_id: @name.id,
          incertae_sedis_parent: names(:bacteria).name,
          incertae_sedis: '1',
          incertae_sedis_text: 'No reliable higher placement is known.'
        }
      }
    end

    placement = @name.reload.placement
    assert_redirected_to name_url(@name)
    assert_predicate placement, :preferred?
    assert_equal names(:bacteria), placement.parent
    assert_predicate placement, :incertae_sedis?
    assert_equal(
      'No reliable higher placement is known.',
      placement.incertae_sedis_text.to_plain_text
    )
    assert_nil @name.parent
  end

  test 'creates a preferred non-incertae sedis placement' do
    assert_difference('Placement.count', 1) do
      post placements_url, params: {
        placement: {
          name_id: @name.id,
          parent: names(:escherichia).name,
          incertae_sedis: '0'
        }
      }
    end

    placement = @name.reload.placement
    assert_redirected_to name_url(@name)
    assert_predicate placement, :preferred?
    assert_equal names(:escherichia), placement.parent
    assert_not_predicate placement, :incertae_sedis?
    assert_equal names(:escherichia), @name.parent
  end
end
