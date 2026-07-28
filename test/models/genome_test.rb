require 'test_helper'

class GenomeTest < ActiveSupport::TestCase
  test 'does not relink sequencing experiments when unrelated attributes change' do
    genome = genomes(:one)
    called = false
    genome.define_singleton_method(:link_sequencing_experiments!) { called = true }

    genome.update!(gc_content: 42.0)

    assert_not called
  end

  test 'relinks sequencing experiments when source_json changes' do
    genome = genomes(:one)
    called = false
    genome.define_singleton_method(:link_sequencing_experiments!) { called = true }

    genome.update!(
      source_database: 'biosample',
      source_accession: 'SAMN00000001',
      source_json: { retrieved_at: Time.now, samples: {} }.to_json
    )

    assert called
  end

  test 'links genome to sequencing experiments matching either biosample accession field' do
    genome = Genome.create!(
      database: 'assembly',
      accession: 'GCA_000000001.1',
      source_database: 'sra',
      source_accession: 'SRX00000001',
      source_json: {
        retrieved_at: Time.now,
        samples: { SAMN00000001: { biosample_accessions: ['MyString'] } }
      }.to_json
    )

    assert_includes genome.sequencing_experiments, sequencing_experiments(:one)
    assert_includes genome.sequencing_experiments, sequencing_experiments(:two)
  end

  test 'unlinks sequencing experiments that no longer match biosample accession' do
    genome = Genome.create!(
      database: 'assembly',
      accession: 'GCA_000000002.1',
      source_database: 'sra',
      source_accession: 'SRX00000002',
      source_json: {
        retrieved_at: Time.now,
        samples: { SAMN00000001: { biosample_accessions: ['MyString'] } }
      }.to_json
    )
    assert_not_empty genome.sequencing_experiments

    genome.update!(source_json: { retrieved_at: Time.now, samples: {} }.to_json)

    assert_empty genome.sequencing_experiments.reload
  end

  test 'unlink check agrees with link check on secondary biosample accessions' do
    one = sequencing_experiments(:one) # biosample_accession: 'MyString'
    two = SequencingExperiment.create!(
      sra_accession: 'SRXALT', biosample_accession_2: 'AltAccession'
    )

    # source_database :biosample: source_accession is the primary accession,
    # while source_json additionally lists a secondary/alternate accession
    # for the same sample, as external_biosample_hash builds it.
    genome = Genome.create!(
      database: 'assembly',
      accession: 'GCA_000000003.1',
      source_database: 'biosample',
      source_accession: 'MyString',
      source_json: {
        retrieved_at: Time.now,
        samples: { MyString: { biosample_accessions: %w[MyString AltAccession] } }
      }.to_json
    )
    assert_includes genome.sequencing_experiments, one
    assert_includes genome.sequencing_experiments, two

    # Re-running the linking logic with unchanged data must not unlink the
    # secondary-accession match.
    genome.send(:link_sequencing_experiments!)

    assert_includes genome.sequencing_experiments.reload, one
    assert_includes genome.sequencing_experiments.reload, two
  end

  test 'source_hash reflects the current source_json after in-memory reassignment' do
    genome = Genome.create!(
      database: 'assembly',
      accession: 'GCA_000000004.1',
      source_database: 'sra',
      source_accession: 'SRX00000004',
      source_json: { retrieved_at: Time.now, samples: { SAMN1: {} } }.to_json
    )
    assert genome.source_hash[:samples].key?(:SAMN1)

    genome.source_json = { retrieved_at: Time.now, samples: { SAMN2: {} } }.to_json

    assert_not genome.source_hash[:samples].key?(:SAMN1)
    assert genome.source_hash[:samples].key?(:SAMN2)
  end
end
