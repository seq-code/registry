require 'test_helper'

class Name::PublicHistoryTest < ActiveSupport::TestCase
  setup do
    @name = names(:escherichia_coli)
    @history = Name::PublicHistory.new(@name)
  end

  test 'shows public attributes and external identifiers but not cached data or workflow controls' do
    @name.update!(
      authority: 'Castellani and Chalmers 1919', gtdb_accession: 's__Escherichia coli',
      gbif_json: '{}', queued_external: Time.current, protect_from_lpsn: 'name'
    )

    assert_equal({
      'authority' => [nil, 'Castellani and Chalmers 1919'],
      'gtdb_accession' => [nil, 's__Escherichia coli']
    }, latest_change)
  end

  test 'omits name creation and versions without public changes' do
    name = Name.create!(name: 'Escherichia ruysiae', rank: 'species')
    name.update!(gbif_json: '{}')

    assert_empty Name::PublicHistory.new(name).versions(page: 1)
  end

  test 'shows adding an etymology' do
    @name.update!(etymology_xx_lang: 'N.L.', etymology_xx_description: 'of the colon')

    assert_equal({ 'etymology' => [
      { 'name' => 'Escherichia coli', 'etymology_xx_lang' => nil,
        'etymology_xx_description' => nil },
      { 'name' => 'Escherichia coli', 'etymology_xx_lang' => 'N.L.',
        'etymology_xx_description' => 'of the colon' }
    ] }, latest_change)
  end

  test 'shows changing an etymology with its unchanged parts' do
    @name.update!(etymology_xx_lang: 'N.L.', etymology_xx_description: 'of the colon')
    @name.update!(etymology_xx_description: 'from the colon')

    assert_equal({ 'etymology' => [
      { 'name' => 'Escherichia coli', 'etymology_xx_lang' => 'N.L.',
        'etymology_xx_description' => 'of the colon' },
      { 'name' => 'Escherichia coli', 'etymology_xx_lang' => 'N.L.',
        'etymology_xx_description' => 'from the colon' }
    ] }, latest_change)
  end

  test 'shows renaming with the etymology under each name' do
    @name.update!(etymology_xx_lang: 'N.L.', etymology_xx_description: 'of the colon')
    @name.update!(name: 'Escherichia colonica')

    assert_equal({
      'name' => ['Escherichia coli', 'Escherichia colonica'],
      'etymology' => [
        { 'name' => 'Escherichia coli', 'etymology_xx_lang' => 'N.L.',
          'etymology_xx_description' => 'of the colon' },
        { 'name' => 'Escherichia colonica', 'etymology_xx_lang' => 'N.L.',
          'etymology_xx_description' => 'of the colon' }
      ]
    }, latest_change)
  end

  test 'shows setting a nomenclatural type' do
    @name.update!(nomenclatural_type: strains(:one))

    assert_equal({ 'nomenclatural_type' => [[nil, nil], ['Strain', strains(:one).id]] },
                 latest_change)
  end

  test 'shows changing a nomenclatural type' do
    @name.update!(nomenclatural_type: strains(:one))
    @name.update!(nomenclatural_type: strains(:two))

    assert_equal({ 'nomenclatural_type' => [
      ['Strain', strains(:one).id], ['Strain', strains(:two).id]
    ] }, latest_change)
  end

  test 'shows removing a nomenclatural type' do
    @name.update!(nomenclatural_type: strains(:one))
    @name.update!(nomenclatural_type: nil)

    assert_equal({ 'nomenclatural_type' => [['Strain', strains(:one).id], [nil, nil]] },
                 latest_change)
  end

  test 'shows linking a publication' do
    PublicationName.create!(name: @name, publication: publications(:one))

    assert_equal({ 'linked' => [false, true] }, latest_change)
  end

  test 'shows unlinking a publication' do
    link = PublicationName.create!(name: @name, publication: publications(:one))
    link.soft_delete!

    assert_equal({ 'linked' => [true, false] }, latest_change)
  end

  test 'shows relinking a publication' do
    link = PublicationName.create!(name: @name, publication: publications(:one))
    link.soft_delete!
    link.update!(deleted_at: nil)

    assert_equal({ 'linked' => [false, true] }, latest_change)
  end

  test 'shows linking a placement' do
    Placement.create!(name: @name, parent: names(:escherichia))

    assert_equal({ 'linked' => [false, true] }, latest_change)
  end

  test 'shows changing a placement' do
    placement = Placement.create!(name: @name, parent: names(:escherichia))
    placement.update!(publication: publications(:one))

    assert_equal({ 'publication_id' => [nil, publications(:one).id] }, latest_change)
  end

  test 'shows unlinking a placement' do
    placement = Placement.create!(name: @name, parent: names(:escherichia))
    placement.soft_delete!

    assert_equal({ 'linked' => [true, false] }, latest_change)
  end

  test 'lists name and relationship changes together newest first' do
    PublicationName.create!(name: @name, publication: publications(:one))
    @name.update!(authority: 'Castellani and Chalmers 1919')

    versions = @history.versions(page: 1)

    assert_equal 2, versions.size
    assert_equal({ 'authority' => [nil, 'Castellani and Chalmers 1919'] },
                 @history.changes_for(versions.first))
    assert_equal({ 'linked' => [false, true] }, @history.changes_for(versions.second))
  end

  test 'excludes placements of other names' do
    Placement.create!(name: names(:escherichia_colie), parent: names(:escherichia))

    assert_empty @history.versions(page: 1)
  end

  private

  def latest_change
    @history.changes_for(@history.versions(page: 1).first)
  end
end
