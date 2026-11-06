require 'test_helper'

class Names::HistoriesHelperTest < ActionView::TestCase
  setup do
    @name = names(:escherichia_coli)
  end

  test 'diffs text attributes and escapes their content' do
    @name.update!(authority: '< Castellani >')
    @name.update!(authority: '& Castellani !')

    assert_equal [[
      'Authority',
      '<del class="text-danger">&lt;</del> Castellani <del class="text-danger">&gt;</del>',
      '<ins class="text-success">&amp;</ins> Castellani <ins class="text-success">!</ins>'
    ]], rows_for_latest_version
  end

  test 'diffs the full etymology' do
    @name.update!(etymology_xx_lang: 'N.L.', etymology_xx_description: 'of the colon')
    @name.update!(etymology_xx_description: 'from the colon')

    (label, before, after), = rows_for_latest_version
    assert_equal 'Etymology', label
    assert_includes before, '<del class="text-danger">of</del> the colon'
    assert_includes after, '<ins class="text-success">from</ins> the colon'
  end

  test 'diffs rich text as sanitized HTML' do
    @name.update!(description: '<div>A <strong>gut</strong> bacterium</div>')
    @name.update!(description: '<div>A <strong>gut</strong> <script>alert(1)</script>bacterium <em>E. coli</em></div>')

    (label, before, after), = rows_for_latest_version
    assert_equal 'Description', label
    assert_equal '<div>A <strong>gut</strong> bacterium</div>', before
    assert_not_includes after, '<script>'
    assert_includes after, '<em><ins class="text-success">E. coli</ins></em>'
  end

  test 'links related records and retains deleted references' do
    basonym = Name.create!(name: 'Bacterium coli', rank: 'species')
    @name.update!(basonym: basonym)

    assert_equal [['Basonym', '—', link_to(basonym.display, basonym)]], rows_for_latest_version

    @name.update!(basonym: nil)
    basonym.destroy!

    assert_equal [['Basonym', "Name ##{basonym.id} (deleted)", '—']], rows_for_latest_version
  end

  test 'shows a polymorphic reference as one row using the type on each side' do
    @name.update!(nomenclatural_type: strains(:one))
    @name.update!(nomenclatural_type: genomes(:one))

    assert_equal [[
      'Nomenclatural type',
      link_to(strains(:one).display, strains(:one)),
      link_to(genomes(:one).display, genomes(:one))
    ]], rows_for_latest_version
  end

  test 'does not resolve recorded types that are not models' do
    assert_equal 'Kernel #1 (deleted)', send(:history_record_link, 'Kernel', 1)
  end

  test 'labels name status codes' do
    @name.update!(status: 5)

    assert_equal 'Draft', rows_for_latest_version.first.last
  end

  test 'heads changes to linked records with what happened' do
    link = PublicationName.create!(name: @name, publication: publications(:one))
    link.update!(emends: true)
    citation = link_to(publications(:one).display, publications(:one))

    assert_equal [
      ['Publication link changed'],
      ['Publication', citation, citation],
      %w[Emends No Yes]
    ], rows_for_latest_version
  end

  private

  def rows_for_latest_version
    history = Name::PublicHistory.new(@name)
    version = history.versions(page: 1).first
    history_rows(version, history.changes_for(version))
  end
end
