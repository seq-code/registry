require 'minitest/autorun'
require_relative '../../lib/html_diff'

class HtmlDiffTest < Minitest::Test
  def test_marks_changed_text_inside_each_sides_own_markup
    assert_equal [
      '<div>A gut bacterium</div>',
      '<div>A <ins class="text-success">commensal </ins>gut bacterium</div>'
    ], HtmlDiff.diff('<div>A gut bacterium</div>', '<div>A commensal gut bacterium</div>')
  end

  def test_marks_a_replaced_phrase_as_one_change
    assert_equal [
      '<div><del class="text-danger">of the colon</del></div>',
      '<div><ins class="text-success">from a gut</ins></div>'
    ], HtmlDiff.diff('<div>of the colon</div>', '<div>from a gut</div>')
  end

  def test_does_not_mark_tags
    before, after = HtmlDiff.diff('<div>E. coli</div>', '<div><strong>E. coli</strong></div>')

    assert_equal '<div>E. coli</div>', before
    assert_equal '<div><strong>E. coli</strong></div>', after
  end

  def test_treats_nothing_as_empty
    assert_equal ['', '<div><ins class="text-success">E. coli</ins></div>'], HtmlDiff.diff(nil, '<div>E. coli</div>')
  end
end
