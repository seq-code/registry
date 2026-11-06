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

  test 'omits versions without public changes' do
    @name.update!(gbif_json: '{}')

    assert_empty @history.versions(page: 1)
  end

  test 'shows public attributes a name was created with' do
    name = Name.create!(name: 'Escherichia ruysiae', rank: 'species')

    changes = Name::PublicHistory.new(name).changes_for(name.versions.last)

    assert_equal [nil, 'Escherichia ruysiae'], changes['name']
    assert_not_includes changes, 'syllabication'
  end

  test 'groups an etymology change with its unchanged parts and the name' do
    @name.update!(etymology_xx_lang: 'N.L.', etymology_xx_description: 'of the colon')
    @name.update!(etymology_xx_description: 'from the colon')

    assert_equal({ 'etymology' => [
      { 'etymology_xx_lang' => 'N.L.', 'etymology_xx_description' => 'of the colon',
        'name' => 'Escherichia coli' },
      { 'etymology_xx_lang' => 'N.L.', 'etymology_xx_description' => 'from the colon',
        'name' => 'Escherichia coli' }
    ] }, latest_change)
  end

  test 'shows the etymology under each name when renaming' do
    @name.update!(etymology_xx_lang: 'N.L.', etymology_xx_description: 'of the colon')
    @name.update!(name: 'Escherichia colonica')

    assert_equal ['Escherichia coli', 'Escherichia colonica'], latest_change['name']
    assert_equal ['Escherichia coli', 'Escherichia colonica'],
                 latest_change['etymology'].map { |attributes| attributes['name'] }
  end

  test 'pairs a nomenclatural type with its record type' do
    @name.update!(nomenclatural_type: strains(:one))
    @name.update!(nomenclatural_type: genomes(:one))

    assert_equal({ 'nomenclatural_type' => [
      ['Strain', strains(:one).id], ['Genome', genomes(:one).id]
    ] }, latest_change)
  end

  test 'shows the publication of a changed publication link' do
    link = PublicationName.create!(name: @name, publication: publications(:one))
    link.update!(emends: true)

    assert_equal({
      'publication_id' => [publications(:one).id, publications(:one).id],
      'emends' => [false, true]
    }, latest_change)
  end

  test 'shows the parent of a changed placement' do
    placement = Placement.create!(name: @name, parent: names(:escherichia))
    placement.update!(publication: publications(:one))

    assert_equal({
      'parent_id' => [names(:escherichia).id, names(:escherichia).id],
      'publication_id' => [nil, publications(:one).id]
    }, latest_change)
  end

  test 'shows public rich texts of the name' do
    @name.update!(description: 'A gut bacterium', notes: 'Check the type strain')

    versions = @history.versions(page: 1)

    assert_equal 1, versions.size
    assert_equal 'description', versions.first.changeset['name'].compact.first
  end

  test 'lists name and relationship changes together newest first' do
    PublicationName.create!(name: @name, publication: publications(:one))
    @name.update!(authority: 'Castellani and Chalmers 1919')

    versions = @history.versions(page: 1)

    assert_equal %w[Name PublicationName], versions.map(&:record_type)
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
