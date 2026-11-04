require 'test_helper'

class CommitteeTermTest < ActiveSupport::TestCase
  test 'terms line up with the community membership cohorts' do
    assert_equal(2023, CommitteeTerm.first_start_year)
    assert_equal(
      User::FIRST_COMMUNITY_MEMBERSHIP_COHORT_END.year,
      CommitteeTerm.new(CommitteeTerm.first_start_year).end_year
    )
  end

  test 'start_year_for finds the term in office on a date' do
    assert_equal(2023, CommitteeTerm.start_year_for(Date.new(2023, 1, 1)))
    assert_equal(2023, CommitteeTerm.start_year_for(Date.new(2026, 12, 31)))
    assert_equal(2027, CommitteeTerm.start_year_for(Date.new(2027, 1, 1)))
    assert_equal(2031, CommitteeTerm.start_year_for(Date.new(2033, 6, 1)))
  end

  test 'find returns defined terms only' do
    assert_equal(2023, CommitteeTerm.find('2023').start_year)
    assert_equal(2027, CommitteeTerm.find(2027).start_year)
    %w[1999 2025 abcd 2023x].each do |year|
      assert_raises(ActiveRecord::RecordNotFound) { CommitteeTerm.find(year) }
    end
  end

  test 'current is the term in office, or the latest one defined' do
    assert_equal(
      CommitteeTerm.new(2023), CommitteeTerm.current(Date.new(2026, 10, 29))
    )
    assert_equal(
      CommitteeTerm.new(2027), CommitteeTerm.current(Date.new(2027, 1, 1))
    )
    assert_equal(
      CommitteeTerm.new(CommitteeTerm.years.max),
      CommitteeTerm.current(Date.new(2100, 1, 1))
    )
  end

  test 'started excludes upcoming terms' do
    date = Date.new(2026, 10, 29)

    assert_includes(CommitteeTerm.started(date), CommitteeTerm.new(2023))
    assert_not_includes(CommitteeTerm.started(date), CommitteeTerm.new(2027))
  end

  test 'label, past, and upcoming' do
    term = CommitteeTerm.new(2023)

    assert_equal('2023–2026', term.label)
    assert_equal('2023', term.to_param)
    assert_not(term.past?(Date.new(2026, 12, 31)))
    assert(term.past?(Date.new(2027, 1, 1)))
    assert(CommitteeTerm.new(2027).upcoming?(Date.new(2026, 12, 31)))
    assert_not(CommitteeTerm.new(2027).upcoming?(Date.new(2027, 1, 1)))
  end

  test 'members_count is live for the current term only' do
    users(:contributor).update!(
      community_member: true, community_member_expires_on: Date.new(2026, 12, 31)
    )
    date = Date.new(2026, 10, 29)
    live = travel_to(date) { User.community_members_active.count }

    assert_operator(live, :>, 0)
    travel_to(date) do
      assert_equal(live, CommitteeTerm.new(2023).members_count)
      assert_nil(CommitteeTerm.new(2027).members_count)
    end
    travel_to(Date.new(2027, 2, 1)) do
      assert_equal(144, CommitteeTerm.new(2023).members_count)
    end
  end

  test 'people are those serving in the term, in people.yml order' do
    people = CommitteeTerm.new(2023).people

    assert_equal(:chuvochina, people.keys.first)
    assert_equal('Barny Whitman', people[:whitman][:name])
    assert_equal(23, people.size)
    assert_includes(CommitteeTerm.new(2027).people, :konstantinidis_2027)
    assert_not_includes(CommitteeTerm.new(2027).people, :konstantinidis)
  end

  test 'every term only references known people and described bodies' do
    CommitteeTerm.years.each do |year|
      term = CommitteeTerm.new(year)

      assert_nothing_raised { term.people }
      term.bodies.each_key do |body|
        partial = Rails.root.join(
          'app', 'views', 'page', 'committee', "_#{body}.html.erb"
        )
        assert(File.exist?(partial), "Missing description for #{body}")
      end
    end
  end
end
