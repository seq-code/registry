require 'test_helper'

class TagsHelperTest < ActionView::TestCase
  test 'name_tag_proposer shows the confidence as a hover title' do
    name_tag = name_tags(:escherichia_coli_toponym)
    name_tag.notes = 'confidence: high'

    assert_dom_equal(
      '<abbr title="high confidence">llm</abbr>', name_tag_proposer(name_tag)
    )
  end

  test 'name_tag_proposer is plain text without a confidence' do
    assert_equal('llm', name_tag_proposer(name_tags(:escherichia_coli_toponym)))
    assert_equal('unknown', name_tag_proposer(name_tags(:draft_toponym)))
  end
end
