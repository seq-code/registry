require 'test_helper'

class VersionedTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test 'records the current user as the version author' do
    name = names(:escherichia_coli)
    Current.user = users(:curator)
    name.update!(authority: 'Smith')
    Current.reset
    name.update!(authority: 'Jones')

    assert_equal [users(:curator), nil], name.versions.order(:id).last(2).map(&:user)
  end
end
