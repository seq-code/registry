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

end
