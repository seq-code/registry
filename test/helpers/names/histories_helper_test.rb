require 'test_helper'

class Names::HistoriesHelperTest < ActionView::TestCase
  test 'groups nearby etymology edits into one span' do
    changes = [
      { name: 'E. coli', etymology_xx_description: 'of the colon' },
      { name: 'E. coli', etymology_xx_description: 'from the colon' }
    ]
    before, after = history_values(changes, attribute: 'etymology')

    assert_equal 'coli, <del class="text-danger">of</del> the colon', before
    assert_equal 'coli, <ins class="text-success">from</ins> the colon', after
  end

  test 'diffs rich text as sanitized HTML' do
    changes = ['<div>A <strong>gut</strong> bacterium</div>',
               '<div>A <strong>gut</strong> <script>alert(1)</script>bacterium <em>E. coli</em></div>']
    before, after = history_values(changes, attribute: 'description')

    assert_equal '<div>A <strong>gut</strong> bacterium</div>', before
    assert_not_includes after, '<script>'
    assert_includes after, '<em><ins class="text-success">E. coli</ins></em>'
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
    %w[proposed_in_id corrigendum_in_id assigned_in_id].each do |attribute|
      assert_equal [citation, '—'],
                   history_values([publication.id, nil], attribute: attribute)
      assert_equal ['—', citation],
                   history_values([nil, publication.id], attribute: attribute)
    end
  end

  test 'renders name relationships as links and retains deleted references' do
    name = names(:escherichia)
    %w[parent_id correct_name_id basonym_id redirect_id].each do |attribute|
      assert_equal ['—', link_to(name.display, name)],
                   history_values([nil, name.id], attribute: attribute)
    end

    name.destroy!

    assert_equal ["Name ##{name.id} (deleted)", '—'],
                 history_values([name.id, nil], attribute: 'parent_id')
  end

  test 'renders polymorphic references using the type on each side' do
    strain = strains(:one)
    genome = genomes(:one)
    assert_equal [link_to(strain.display, strain), link_to(genome.display, genome)],
                 history_values(
                   [['Strain', strain.id], ['Genome', genome.id]],
                   attribute: 'nomenclatural_type'
                 )
    assert_equal [link_to(genome.display, genome), '—'],
                 history_values([['Genome', genome.id], [nil, nil]],
                                attribute: 'nomenclatural_type')
  end

  test 'does not resolve polymorphic types that are not models' do
    assert_equal ['Kernel #1', 'Strain::Missing #2'],
                 history_values([['Kernel', 1], ['Strain::Missing', 2]],
                                attribute: 'nomenclatural_type')
  end

  test 'formats name status labels without diffing them' do
    assert_equal ['Draft', 'Submitted'], history_values([5, 10], attribute: 'status')
    assert_equal ['—', '99'], history_values([nil, 99], attribute: 'status')
    assert_equal ['5', '10'], history_values(
      [5, 10], attribute: 'status', record_type: 'PublicationName'
    )
  end
end
