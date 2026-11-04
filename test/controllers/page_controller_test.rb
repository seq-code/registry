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

  test 'committee shows the current term' do
    travel_to(Date.new(2026, 10, 29)) do
      get(page_committee_path)
    end

    assert_response(:success)
    assert_select('h2', text: 'Executive Board')
    assert_select('b', text: 'Barny Whitman')
    assert_select('.alert', count: 0)
    assert_select('.crumbs', count: 0)
  end

  test 'committee shows the live count of community members' do
    travel_to(Date.new(2026, 10, 29)) do
      users(:contributor).update!(
        community_member: true,
        community_member_expires_on: Date.new(2026, 12, 31)
      )
      count = User.community_members_active.count
      get(page_committee_path)

      assert_select('dd', text: /Currently #{count} members globally/)
    end
  end

  test 'committee does not link to upcoming terms' do
    travel_to(Date.new(2026, 10, 29)) do
      get(page_committee_path)
    end

    assert_select('a[href*=?]', page_committee_path(term: 2027), count: 0)
  end

  test 'committee shows a specific term with crumbs' do
    travel_to(Date.new(2026, 10, 29)) do
      get(page_committee_path(term: 2023))
    end

    assert_response(:success)
    assert_select('.crumbs a[href=?]', page_committee_path, text: 'Committee')
    assert_select('.crumbs span.active', text: '2023–2026')
    assert_select('b', text: 'Barny Whitman')
  end

  test 'upcoming committee terms are public but flagged' do
    travel_to(Date.new(2026, 10, 29)) do
      get(page_committee_path(term: 2027))
    end

    assert_response(:success)
    assert_select('.alert-info', text: /has not started yet/)
    assert_select('dd', text: /To be announced/)
  end

  test 'past committee terms link to the current one' do
    travel_to(Date.new(2027, 2, 1)) do
      get(page_committee_path(term: 2023))
    end

    assert_response(:success)
    assert_select('.alert-secondary', text: /2023–2026 term/)
    assert_select('.alert-secondary a[href=?]', page_committee_path)
    assert_select('b', text: 'Barny Whitman')
    assert_select('dd', text: /144 members globally by the end of the term/)
  end

  test 'the next term becomes current when it starts' do
    travel_to(Date.new(2027, 1, 1)) do
      get(page_committee_path)
    end

    assert_select('b', text: 'Barny Whitman', count: 0)
    assert_select('.alert', count: 0)
  end

  test 'the committee short link still points to the current committee' do
    get('/link/committee')

    assert_redirected_to(page_committee_path)
  end

  test 'unknown committee terms are not found' do
    assert_raises(ActiveRecord::RecordNotFound) do
      get(page_committee_path(term: 1999))
    end
  end
end
