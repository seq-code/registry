require 'minitest/autorun'
require_relative '../../lib/text_diff'

class TextDiffTest < Minitest::Test
  def test_groups_nearby_edits_and_preserves_surrounding_text
    assert_equal [
      [true, 'E. coli: ', 'E. coli: '],
      [false, 'of', 'from'],
      [true, ' the colon', ' the colon']
    ], TextDiff.chunks('E. coli: of the colon', 'E. coli: from the colon')
  end

  def test_keeps_distant_edits_separate
    assert_equal [
      [false, '<', '&'],
      [true, ' E. coli ', ' E. coli '],
      [false, '>', '!']
    ], TextDiff.chunks('< E. coli >', '& E. coli !')
  end

  def test_represents_additions_and_removals_with_an_empty_side
    assert_equal [[true, 'E. coli', 'E. coli'], [false, '', ' strain']],
                 TextDiff.chunks('E. coli', 'E. coli strain')
    assert_equal [[true, 'E. coli', 'E. coli'], [false, ' strain', '']],
                 TextDiff.chunks('E. coli strain', 'E. coli')
  end
end
