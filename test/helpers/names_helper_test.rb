require 'test_helper'

class NamesHelperTest < ActionView::TestCase
  test 'groups nearby etymology edits into one span' do
    changes = [
      { name: 'E. coli', etymology_xx_description: 'of the colon' },
      { name: 'E. coli', etymology_xx_description: 'from the colon' }
    ]
    before, after = history_values(changes, attribute: 'etymology')

    assert_equal 'coli, <del class="text-danger">of</del> the colon', before
    assert_equal 'coli, <ins class="text-success">from</ins> the colon', after
  end

  test 'keeps distant edits separate and escapes their content' do
    changes = [
      { name: 'E. coli', etymology_xx_description: '< E. coli >' },
      { name: 'E. coli', etymology_xx_description: '& E. coli !' }
    ]
    before, after = history_values(changes, attribute: 'etymology')

    assert_equal 'coli, <del class="text-danger">&lt;</del> E. coli <del class="text-danger">&gt;</del>', before
    assert_equal 'coli, <ins class="text-success">&amp;</ins> E. coli <ins class="text-success">!</ins>', after
  end

  test 'renders publication changes as citations' do
    publication = publications(:one)
    citation = link_to(publication.short_citation, publication)
    assert_equal [citation, '—'],
                 history_values([publication.id, nil], attribute: 'proposed_in_id')
    assert_equal ['—', citation],
                 history_values([nil, publication.id], attribute: 'proposed_in_id')
  end

  test 'diffs text additions and removals in either record context' do
    %w[Name PublicationName].each do |record_type|
      assert_equal ['—', '<ins class="text-success">Smith &amp; Jones</ins>'],
                   history_values([nil, 'Smith & Jones'], attribute: 'authority', record_type: record_type)
      assert_equal ['<del class="text-danger">Smith &amp; Jones</del>', '—'],
                   history_values(['Smith & Jones', nil], attribute: 'authority', record_type: record_type)
    end
  end

  test 'formats name status labels without diffing them' do
    assert_equal ['Draft', 'Submitted'], history_values([5, 10], attribute: 'status')
    assert_equal ['—', '99'], history_values([nil, 99], attribute: 'status')
    assert_equal ['5', '10'], history_values(
      [5, 10], attribute: 'status', record_type: 'PublicationName'
    )
  end

  test 'renders publication relationship values in their own record context' do
    %w[linked emends not_valid_proposal].each do |attribute|
      assert_equal ['No', 'Yes'], history_values(
        [false, true], attribute: attribute, record_type: 'PublicationName'
      )
      assert_equal ['Yes', 'No'], history_values(
        [true, false], attribute: attribute, record_type: 'PublicationName'
      )
    end
  end

  test 'renders a retained publication id when the publication no longer exists' do
    publication = publications(:no_doi)
    publication.destroy!

    assert_equal ['—', "Publication ##{publication.id} (deleted)"],
                 history_values([nil, publication.id], attribute: 'proposed_in_id')
  end

  test 'preserves nonboolean publication relationship values' do
    ids = [publications(:one).id, publications(:no_doi).id]

    assert_equal ids.map(&:to_s), history_values(
      ids, attribute: 'publication_id', record_type: 'PublicationName'
    )
  end
end
