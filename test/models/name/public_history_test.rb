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
      'gtdb_accession' => [nil, 'GB_GCA_000005845.2'],
      'etymology_xx_lang' => ['N.L.', 'N.L.'],
      'etymology_xx_description' => ['of the colon', 'from the colon']
    })

    assert_equal({
      'authority' => [nil, 'Smith'],
      'proposed_in_id' => [nil, publications(:one).id],
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
    @name.update!(gtdb_accession: 'GB_GCA_000005845.2')
    link.update!(emends: true)

    first_page = @history.versions(page: 1)
    second_page = @history.versions(page: 2)

    assert_equal 25, first_page.size
    assert_equal({ 'emends' => [false, true] },
                 @history.changes_for(first_page.first))
    assert_equal [unlinked_version, linked_version], second_page
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

  test 'includes publication relationship changes without an attribute allowlist' do
    values = [publications(:one).id, publications(:no_doi).id]
    version = Version.new(record_type: 'PublicationName', operation: 'update', changeset: {
      'publication_id' => values
    })

    assert_equal({ 'publication_id' => values }, @history.changes_for(version))
  end
end
