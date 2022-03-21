require "test_helper"

class TutorialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tutorial = tutorials(:one)
  end

  test "should get index" do
    get tutorials_url
    assert_response :success
  end

  test "should get new" do
    get new_tutorial_url
    assert_response :success
  end

  test "should create tutorial" do
    assert_difference('Tutorial.count') do
      post tutorials_url, params: { tutorial: { ongoing: @tutorial.ongoing, pipeline: @tutorial.pipeline, step: @tutorial.step, user_id: @tutorial.user_id } }
    end

    assert_redirected_to tutorial_url(Tutorial.last)
  end

  test "should show tutorial" do
    get tutorial_url(@tutorial)
    assert_response :success
  end

  test "should get edit" do
    get edit_tutorial_url(@tutorial)
    assert_response :success
  end

  test "should update tutorial" do
    patch tutorial_url(@tutorial), params: { tutorial: { ongoing: @tutorial.ongoing, pipeline: @tutorial.pipeline, step: @tutorial.step, user_id: @tutorial.user_id } }
    assert_redirected_to tutorial_url(@tutorial)
  end

  test "should destroy tutorial" do
    assert_difference('Tutorial.count', -1) do
      delete tutorial_url(@tutorial)
    end

    assert_redirected_to tutorials_url
  end
end
