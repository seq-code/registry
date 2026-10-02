require 'test_helper'

class NamesHelperTest < ActionView::TestCase
  test 'groups nearby etymology edits into one span' do
    changes = [
      { name: 'E. coli', etymology_xx_description: 'of the colon' },
      { name: 'E. coli', etymology_xx_description: 'from the colon' }
    ]
    before = history_before_value(changes, attribute: 'etymology')
    after = history_after_value(changes, attribute: 'etymology')

    assert_equal 'coli, <del class="text-danger">of</del> the colon', before
    assert_equal 'coli, <ins class="text-success">from</ins> the colon', after
  end

  test 'keeps distant edits separate and escapes their content' do
    changes = [
      { name: 'E. coli', etymology_xx_description: '< E. coli >' },
      { name: 'E. coli', etymology_xx_description: '& E. coli !' }
    ]
    before = history_before_value(changes, attribute: 'etymology')
    after = history_after_value(changes, attribute: 'etymology')

    assert_equal 'coli, <del class="text-danger">&lt;</del> E. coli <del class="text-danger">&gt;</del>', before
    assert_equal 'coli, <ins class="text-success">&amp;</ins> E. coli <ins class="text-success">!</ins>', after
  end

end
