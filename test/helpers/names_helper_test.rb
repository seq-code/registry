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

  test 'renders proposed publication changes as citations' do
    publication = publications(:one)
    citation = link_to(publication.short_citation, publication)
    assert_equal [citation, '—'],
                 history_values([publication.id, nil], attribute: 'proposed_in_id')
    assert_equal ['—', citation],
                 history_values([nil, publication.id], attribute: 'proposed_in_id')
  end
  test 'renders a retained publication id when the publication no longer exists' do
    publication = publications(:no_doi)
    publication.destroy!

    assert_equal ['—', "Publication ##{publication.id} (deleted)"],
                 history_values([nil, publication.id], attribute: 'proposed_in_id')
  end
end
