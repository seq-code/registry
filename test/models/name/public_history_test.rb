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

  test 'combines publication links unlinks and relinks with name updates newest first' do
    publication = publications(:one)
    start = Time.zone.local(2026, 10, 1, 12)
    link = nil
    travel_to(start) do
      link = PublicationName.create!(name: @name, publication: publication)
    end
    travel_to(start + 1.minute) { @name.update!(authority: 'Smith') }
    travel_to(start + 2.minutes) { link.unlink! }
    travel_to(start + 3.minutes) { link.update!(unlinked_at: nil) }

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

  test 'filters nonpublic changes before paginating the combined history' do
    link = PublicationName.create!(name: @name, publication: publications(:one))
    linked_version = link.versions.last
    link.unlink!
    unlinked_version = link.versions.last
    24.times { |index| @name.update!(authority: "Smith #{index}") }
    @name.update!(protect_from_lpsn: 'name')
    link.update!(emends: true)

    first_page = @history.versions(page: 1)
    second_page = @history.versions(page: 2)

    assert_equal 25, first_page.size
    assert_equal({ 'emends' => [false, true] },
                 @history.changes_for(first_page.first))
    assert_equal [unlinked_version, linked_version], second_page
  end

  test 'includes changes to scientific relationships and publication roles' do
    @name.update!(
      parent: nil, correct_name: names(:escherichia_colie),
      basonym: names(:escherichia_colie), redirect: names(:escherichia_colie),
      corrigendum_in: publications(:one), assigned_in: publications(:one),
      corrigendum_kind: 'publication', genome_id: genomes(:one).id,
      genome_strain: 'ATCC 11775'
    )

    changes = @history.changes_for(@name.versions.last)

    assert_equal [names(:escherichia).id, nil], changes['parent_id']
    %w[correct_name_id basonym_id redirect_id].each do |attribute|
      assert_equal [nil, names(:escherichia_colie).id], changes[attribute]
    end
    %w[corrigendum_in_id assigned_in_id].each do |attribute|
      assert_equal [nil, publications(:one).id], changes[attribute]
    end
    assert_equal [nil, 'publication'], changes['corrigendum_kind']
    assert_equal [nil, genomes(:one).id], changes['genome_id']
    assert_equal [nil, 'ATCC 11775'], changes['genome_strain']
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

  test 'identifies the publication for each relationship history including unlinks' do
    first_link = PublicationName.create!(name: @name, publication: publications(:one))
    second_link = PublicationName.create!(name: @name, publication: publications(:no_doi))
    first_link.unlink!

    first_link.versions.each do |version|
      assert_equal publications(:one).id, @history.publication_id_for(version)
    end
    assert_equal publications(:no_doi).id, @history.publication_id_for(second_link.versions.last)
  end

  test 'shows publication role additions and removals alongside unlink changes' do
    link = PublicationName.create!(name: @name, publication: publications(:one))
    link.update!(emends: true, not_valid_proposal: true)

    assert_equal({
      'emends' => [false, true],
      'not_valid_proposal' => [false, true]
    }, @history.changes_for(link.versions.last))

    link.update!(emends: false, not_valid_proposal: false, unlinked_at: Time.current)

    assert_equal({
      'linked' => [true, false],
      'emends' => [true, false],
      'not_valid_proposal' => [true, false]
    }, @history.changes_for(link.versions.last))
  end

  test 'omits timestamp-only unlink changes while retaining role changes' do
    version = Version.new(record_type: 'PublicationName', operation: 'update', changeset: {
      'unlinked_at' => ['2026-10-01T12:00:00Z', '2026-10-01T12:01:00Z'],
      'emends' => [false, true]
    })

    assert_equal({ 'emends' => [false, true] }, @history.changes_for(version))
  end

  test 'keeps only allowlisted publication attributes' do
    version = Version.new(record_type: 'PublicationName', operation: 'update', changeset: {
      'publication_id' => [publications(:one).id, publications(:no_doi).id],
      'name_id' => [names(:escherichia_coli).id, names(:escherichia_colie).id],
      'emends' => [false, true]
    })

    assert_equal({ 'emends' => [false, true] }, @history.changes_for(version))
  end
end
