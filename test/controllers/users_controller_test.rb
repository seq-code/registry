require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @contributor = users(:contributor)
    @admin = users(:admin)
    @officer = users(:officer)
  end

  test 'community_member_update saves permitted profile fields' do
    sign_in(@contributor)

    post(
      community_member_update_path,
      params: { user: { given: 'Ada', position: 'Researcher' } }
    )

    assert_redirected_to(dashboard_path(tab: :community_member))
    @contributor.reload
    assert_equal('Ada', @contributor.given)
    assert_equal('Researcher', @contributor.position)
  end

  test 'community_member_update does not allow setting affiliation_ror' do
    sign_in(@contributor)

    post(
      community_member_update_path,
      params: { user: { affiliation_ror: '01an7q238' } }
    )

    assert_nil(@contributor.reload.affiliation_ror)
  end

  test 'community_member_apply marks a pending application when eligible' do
    sign_in(@contributor)
    complete_community_member_profile!(@contributor)
    assert_nil(@contributor.community_member_expires_on)

    post(community_member_apply_path)

    assert_redirected_to(dashboard_path(tab: :community_member))
    assert(@contributor.reload.community_member_applied_at.present?)
  end

  test 'community_member_apply is a no-op outside the renewal window' do
    sign_in(@contributor)
    complete_community_member_profile!(@contributor)
    @contributor.update!(
      community_member: true,
      community_member_expires_on: Date.current + 2.years
    )

    post(community_member_apply_path)

    assert_nil(@contributor.reload.community_member_applied_at)
  end

  test 'community_member_apply is a no-op with an incomplete profile' do
    sign_in(@contributor)
    assert_not(@contributor.community_member_profile_complete?)

    post(community_member_apply_path)

    assert_nil(@contributor.reload.community_member_applied_at)
  end

  test 'community_member_grant approves the application and sets tracking fields' do
    sign_in(@officer)
    @contributor.update!(community_member_applied_at: Time.current)

    post(community_member_grant_path(@contributor))

    @contributor.reload
    assert(@contributor.community_member?)
    assert_nil(@contributor.community_member_applied_at)
    assert_equal(Date.current, @contributor.community_member_started_on)
    assert_equal(
      User.community_membership_cohort_end,
      @contributor.community_member_expires_on
    )
  end

  test 'community_member_grant preserves the original started_on for renewals' do
    sign_in(@officer)
    original_start = Date.new(2019, 3, 1)
    @contributor.update!(
      community_member: true,
      community_member_started_on: original_start,
      community_member_applied_at: Time.current
    )

    post(community_member_grant_path(@contributor))

    assert_equal(original_start, @contributor.reload.community_member_started_on)
  end

  test 'community_member_deny clears the pending application' do
    sign_in(@officer)
    @contributor.update!(community_member_applied_at: Time.current)

    post(community_member_deny_path(@contributor))

    assert_nil(@contributor.reload.community_member_applied_at)
  end

  test 'community_member_grant is not accessible to regular users' do
    sign_in(@contributor)

    post(community_member_grant_path(@contributor))

    assert_response(:redirect)
    assert_not(@contributor.reload.community_member?)
  end

  test 'community_member_grant is not accessible to admins who are not officers' do
    sign_in(@admin)
    @contributor.update!(community_member_applied_at: Time.current)

    post(community_member_grant_path(@contributor))

    assert_response(:redirect)
    assert_not(@contributor.reload.community_member?)
  end

  test 'community_member_deny is not accessible to admins who are not officers' do
    sign_in(@admin)
    @contributor.update!(community_member_applied_at: Time.current)

    post(community_member_deny_path(@contributor))

    assert(@contributor.reload.community_member_applied_at.present?)
  end

  test 'officer dashboard tab renders the applications list and mailto link' do
    sign_in(@officer)
    @contributor.update!(community_member_applied_at: Time.current)

    get(dashboard_path(tab: :officer))

    assert_response(:success)
    assert_match(@contributor.username, response.body)
    assert_match('mailto:seqcode@bio.aau.dk', response.body)
  end

  test 'officer dashboard tab renders with no pending applications or members' do
    sign_in(@officer)

    get(dashboard_path(tab: :officer))

    assert_response(:success)
    assert_match('None pending', response.body)
  end

  test 'admin dashboard tab no longer shows community member applications' do
    sign_in(@admin)
    @contributor.update!(community_member_applied_at: Time.current)

    get(dashboard_path(tab: :admin))

    assert_response(:success)
    assert_no_match('Community member applications', response.body)
  end

  test 'community_member_update stores the custom value for Other position' do
    sign_in(@contributor)

    post(
      community_member_update_path,
      params: {
        user: { position: 'Other', position_other: 'Staff Scientist' }
      }
    )

    assert_equal('Staff Scientist', @contributor.reload.position)
  end

  test 'community_member_update stores the custom value for Other degree' do
    sign_in(@contributor)

    post(
      community_member_update_path,
      params: {
        user: {
          highest_degree: 'Other', highest_degree_other: 'Habilitation'
        }
      }
    )

    assert_equal('Habilitation', @contributor.reload.highest_degree)
  end

  test 'community_member tab disables apply with an incomplete profile' do
    sign_in(@contributor)

    get(dashboard_path(tab: :community_member))

    assert_response(:success)
    assert_select('a.btn.disabled', text: /Apply for/)
    assert_match(
      'Please complete your profile below before applying', response.body
    )
  end

  test 'community_member tab enables apply with a complete profile' do
    sign_in(@contributor)
    complete_community_member_profile!(@contributor)

    get(dashboard_path(tab: :community_member))

    assert_response(:success)
    assert_select('a.btn.disabled', count: 0)
    assert_select('a.btn', text: /Apply for/)
  end

  private

    def complete_community_member_profile!(user)
      user.update!(
        given: 'Ada', family: 'Lovelace', affiliation: 'Analytical Engines',
        department: 'Computing',
        position: User::COMMUNITY_MEMBER_POSITION_OPTIONS.first,
        highest_degree: User::COMMUNITY_MEMBER_DEGREE_OPTIONS.first,
        achievements: 'Wrote the first algorithm',
        membership_societies: 'ISME'
      )
    end
end
