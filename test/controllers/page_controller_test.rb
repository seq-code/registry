require "test_helper"

class PageControllerTest < ActionDispatch::IntegrationTest
  test "should get publications" do
    get page_publications_url
    assert_response :success
  end

  test "should get seqcode" do
    get page_seqcode_url
    assert_response :success
  end
end
