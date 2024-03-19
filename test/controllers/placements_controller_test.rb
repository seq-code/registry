require 'test_helper'

class PlacementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @placement = placements(:one)
  end

  test 'should get index' do
    get placements_url
    assert_response :success
  end

  test 'should get new' do
    get new_placement_url
    assert_response :success
  end

  test 'should create placement' do
    assert_difference('Placement.count') do
      post placements_url, params: { placement: { assigned_by: @placement.assigned_by, child_id: @placement.child_id, parent_id: @placement.parent_id, preferred: @placement.preferred } }
    end

    assert_redirected_to placement_url(Placement.last)
  end

  test 'should show placement' do
    get placement_url(@placement)
    assert_response :success
  end

  test 'should get edit' do
    get edit_placement_url(@placement)
    assert_response :success
  end

  test 'should update placement' do
    patch placement_url(@placement), params: { placement: { assigned_by: @placement.assigned_by, child_id: @placement.child_id, parent_id: @placement.parent_id, preferred: @placement.preferred } }
    assert_redirected_to placement_url(@placement)
  end

  test 'should destroy placement' do
    assert_difference('Placement.count', -1) do
      delete placement_url(@placement)
    end

    assert_redirected_to placements_url
  end
end
