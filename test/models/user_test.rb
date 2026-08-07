require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'community_membership_cohort_end returns the anchor outside the reapply window' do
    assert_equal(
      Date.new(2026, 12, 31),
      User.community_membership_cohort_end(Date.new(2023, 1, 1))
    )
    assert_equal(
      Date.new(2026, 12, 31),
      User.community_membership_cohort_end(Date.new(2026, 6, 29))
    )
  end

  test 'community_membership_cohort_end advances by 4-year blocks' do
    assert_equal(
      Date.new(2030, 12, 31),
      User.community_membership_cohort_end(Date.new(2027, 1, 1))
    )
    assert_equal(
      Date.new(2034, 12, 31),
      User.community_membership_cohort_end(Date.new(2031, 6, 15))
    )
  end

  test 'community_membership_cohort_end rolls over within the reapply window' do
    # The reapply window for the 2026 cohort opens 2026-06-30 (6 months
    # before it ends), so applying/renewing from that point on should grant
    # the following cohort instead of a few leftover months
    assert_equal(
      Date.new(2030, 12, 31),
      User.community_membership_cohort_end(Date.new(2026, 6, 30))
    )
    assert_equal(
      Date.new(2030, 12, 31),
      User.community_membership_cohort_end(Date.new(2026, 8, 7))
    )
    assert_equal(
      Date.new(2030, 12, 31),
      User.community_membership_cohort_end(Date.new(2026, 12, 31))
    )
  end

  test 'community_member_active? requires both the flag and an unexpired date' do
    user = users(:contributor)
    user.community_member = true
    user.community_member_expires_on = Date.current + 1.day
    assert(user.community_member_active?)

    user.community_member_expires_on = Date.current - 1.day
    assert_not(user.community_member_active?)

    user.community_member_expires_on = nil
    assert_not(user.community_member_active?)

    user.community_member = false
    user.community_member_expires_on = Date.current + 1.day
    assert_not(user.community_member_active?)
  end

  test 'can_apply_for_community_membership? is true before a first application' do
    user = users(:contributor)
    assert_nil(user.community_member_expires_on)
    assert(user.can_apply_for_community_membership?)
  end

  test 'can_apply_for_community_membership? is gated to 6 months before expiration' do
    user = users(:contributor)

    user.community_member_expires_on = Date.current + 7.months
    assert_not(user.can_apply_for_community_membership?)

    user.community_member_expires_on = Date.current + 5.months
    assert(user.can_apply_for_community_membership?)

    user.community_member_expires_on = Date.current - 1.day
    assert(user.can_apply_for_community_membership?)
  end

  test 'community_member_applications scopes to users with a pending application' do
    applicant = users(:contributor)
    applicant.update!(community_member_applied_at: Time.current)

    assert_includes(User.community_member_applications, applicant)
    assert_not_includes(User.community_member_applications, users(:curator))
  end

  test 'community_members_active scopes to unexpired members only' do
    active = users(:contributor)
    active.update!(
      community_member: true, community_member_expires_on: Date.current + 1.day
    )
    lapsed = users(:curator)
    lapsed.update!(
      community_member: true, community_member_expires_on: Date.current - 1.day
    )

    assert_includes(User.community_members_active, active)
    assert_not_includes(User.community_members_active, lapsed)
    assert_not_includes(User.community_members_active, users(:admin))
  end

  test 'community_member_profile_complete? requires every profile field' do
    user = users(:contributor)
    assert_not(user.community_member_profile_complete?)

    user.assign_attributes(
      given: 'Ada', family: 'Lovelace', affiliation: 'Analytical Engines',
      department: 'Computing',
      position: User::COMMUNITY_MEMBER_POSITION_OPTIONS.first,
      highest_degree: User::COMMUNITY_MEMBER_DEGREE_OPTIONS.first,
      achievements: 'Wrote the first algorithm'
    )
    assert_not(user.community_member_profile_complete?)

    user.membership_societies = 'ISME'
    assert(user.community_member_profile_complete?)
  end
end
