require 'test_helper'

class NameTest < ActiveSupport::TestCase
  test 'add_to_register adds name to a draft register' do
    name = names(:unregistered)
    register = registers(:draft)

    assert register.draft?
    assert name.add_to_register(register, users(:contributor))
    assert_equal register, name.reload.register
  end

  test 'add_to_register refuses non-draft registers' do
    name = names(:unregistered)
    register = registers(:submitted)

    assert_not register.draft?
    assert_not name.add_to_register(register, users(:contributor))
    assert_includes name.errors[:register], 'must be a draft'
    assert_nil name.reload.register
  end
end
