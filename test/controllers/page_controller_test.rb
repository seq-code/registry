require 'test_helper'

class PageControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'join redirects signed-in users straight to the membership tab' do
    sign_in(users(:contributor))

    get(page_join_path)

    assert_redirected_to(dashboard_path(tab: :community_member))
  end

  test 'join sends signed-out users to sign in, remembering the membership tab' do
    get(page_join_path)

    assert_redirected_to(new_user_session_path)
    assert_equal(
      dashboard_path(tab: :community_member), session['user_return_to']
    )
  end
end
