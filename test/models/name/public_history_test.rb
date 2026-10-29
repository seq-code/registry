require 'test_helper'

class Name::PublicHistoryTest < ActiveSupport::TestCase
  setup do
    @name = names(:escherichia_coli)
    @history = Name::PublicHistory.new(@name)
  end

  test 'keeps public changes and groups etymology snapshots without unchanged companions' do
    version = Version.new(record_type: 'Name', changeset: {
      'name' => ['E. coli', 'E. coli'],
      'authority' => [nil, 'Smith'],
      'proposed_in_id' => [nil, publications(:one).id],
      'gtdb_accession' => [nil, 's__Escherichia coli'],
      'protect_from_lpsn' => [nil, 'name'],
      'etymology_xx_lang' => ['N.L.', 'N.L.'],
      'etymology_xx_description' => ['of the colon', 'from the colon']
    })

    assert_equal({
      'authority' => [nil, 'Smith'],
      'proposed_in_id' => [nil, publications(:one).id],
      'gtdb_accession' => [nil, 's__Escherichia coli'],
      'etymology' => [
        { 'name' => 'E. coli', 'etymology_xx_lang' => 'N.L.',
          'etymology_xx_description' => 'of the colon' },
        { 'name' => 'E. coli', 'etymology_xx_lang' => 'N.L.',
          'etymology_xx_description' => 'from the colon' }
      ]
    }, @history.changes_for(version))
  end

  test 'shows description and etymology text edits as name changes' do
    @name.update!(description: 'A gut bacterium', etymology_text: 'From the colon', notes: 'Internal')
    @name.reload.update!(description: 'A commensal gut bacterium')

    changes = @history.versions(page: 1).flat_map { |version| @history.changes_for(version).keys }

    assert_equal %w[description description etymology_text], changes.sort
  end

  test 'combines publication links unlinks and relinks with name updates newest first' do
    publication = publications(:one)
    start = Time.zone.local(2026, 10, 1, 12)
    link = nil
    travel_to(start) do
      link = PublicationName.create!(name: @name, publication: publication)
    end
    travel_to(start + 1.minute) { @name.update!(authority: 'Smith') }
    travel_to(start + 2.minutes) { link.soft_delete! }
    travel_to(start + 3.minutes) { link.update!(deleted_at: nil) }

    versions = @history.versions(page: 1)

    assert_equal [
      { 'linked' => [false, true] },
      { 'linked' => [true, false] },
      { 'authority' => [nil, 'Smith'] },
      { 'linked' => [false, true] }
    ], versions.map { |version| @history.changes_for(version) }
    assert_equal [3, 2, 1, 0].map { |minutes| start + minutes.minutes },
                 versions.map(&:created_at)
  end

  test 'includes external identifiers but excludes cached data and workflow controls' do
    identifiers = {
      ncbi_taxonomy: 562, lpsn_url: 'https://lpsn.dsmz.de/species/escherichia-coli',
      gtdb_accession: 's__Escherichia coli', wikidata_item: 'Q25419',
      wikispecies_entry: 'Escherichia coli'
    }
    @name.update!(identifiers.merge(
      gbif_json: '{}', queued_external: Time.current,
      temporary_editable_at: Time.current, protect_from_lpsn: 'name'
    ))

    assert_equal identifiers.stringify_keys.keys.sort,
                 @history.changes_for(@name.versions.last).keys.sort
  end

  test 'groups polymorphic relationship changes with their unchanged companions' do
    @name.update!(nomenclatural_type: strains(:one))
    @name.update!(nomenclatural_type: strains(:two))

    assert_equal({ 'nomenclatural_type' => [
      ['Strain', strains(:one).id], ['Strain', strains(:two).id]
    ] }, @history.changes_for(@name.versions.last))

    @name.update!(nomenclatural_type_type: 'Genome')

    assert_equal({ 'nomenclatural_type' => [
      ['Strain', strains(:two).id], ['Genome', strains(:two).id]
    ] }, @history.changes_for(@name.versions.last))

    @name.update!(nomenclatural_type: nil)

    assert_equal({ 'nomenclatural_type' => [
      ['Genome', strains(:two).id], [nil, nil]
    ] }, @history.changes_for(@name.versions.last))
  end

  test 'tracks placements through linking, changes, and unlinking' do
    placement = Placement.create!(
      name: @name, parent: names(:bacteria), incertae_sedis: true,
      incertae_sedis_text: 'Family placement unresolved'
    )
    placement.update!(publication: publications(:one))
    placement.soft_delete!

    versions = @history.versions(page: 1)

    assert_equal [
      { 'linked' => [true, false] },
      { 'publication_id' => [nil, publications(:one).id] },
      { 'linked' => [false, true] }
    ], versions.map { |version| @history.changes_for(version) }
  end

  test 'excludes placements of other names' do
    Placement.create!(name: names(:escherichia_colie), parent: names(:escherichia))

    assert_empty @history.versions(page: 1)
  end
end
