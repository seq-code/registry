require 'test_helper'
require 'minitest/mock'
require 'miga'
require 'miga/cli'

class GenomeTest < ActiveSupport::TestCase
  test 'type_of_type identifies the record as a Genome, not its source database' do
    genome = genomes(:one)
    genome.database = 'assembly'

    assert_equal('Genome', genome.type_of_type)
  end

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
    one = sequencing_experiments(:one)
    one.update_column(:biosample_accession, 'SAMN00000001')
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
      source_accession: 'SAMN00000001',
      source_json: {
        retrieved_at: Time.now,
        samples: { SAMN00000001: { biosample_accessions: %w[SAMN00000001 AltAccession] } }
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

  test 'anonymous users cannot edit genomes without names' do
    genome = genomes(:one)
    assert_empty genome.names

    assert_not genome.can_edit?(nil)
    assert genome.can_edit?(users(:contributor))
  end

  # --- Accession formats ---

  def accession_errors(attrs)
    genome = Genome.new(attrs)
    genome.validate
    genome.errors
  end

  test 'accepts valid assembly accessions, single or comma-separated' do
    [
      'GCA_000175575', 'GCF_000175575.2',
      'GCA_030737935.1, GCA_030731815.1', 'GCA_030737935.1,GCF_030731815.1'
    ].each do |acc|
      errors = accession_errors(database: 'assembly', accession: acc)
      assert_empty(errors[:accession], "expected #{acc.inspect} to be valid")
    end
  end

  test 'rejects malformed assembly accessions' do
    [
      'GCA_000175575.2 GCA_000175576.1', 'GCA_00017557', 'ASM1081187v1',
      'GCA_000175575.2,', 'GCA_000175575.2,,GCA_000175576.1', '3445352'
    ].each do |acc|
      errors = accession_errors(database: 'assembly', accession: acc)
      assert_not_empty(errors[:accession], "expected #{acc.inspect} to be invalid")
    end
  end

  test 'accepts valid nucleotide accessions, including WGS and RefSeq' do
    [
      'U00096', 'CP036432.1', 'AUEK00000000', 'BAAIHG010000001',
      'NC_000913.3', 'NZ_CP012345.1', 'NZ_AUEK01000001',
      'CP036432.1, CP036433.1'
    ].each do |acc|
      errors = accession_errors(database: 'nuccore', accession: acc)
      assert_empty(errors[:accession], "expected #{acc.inspect} to be valid")
    end
  end

  test 'rejects non-nucleotide or space-separated nuccore accessions' do
    [
      'CP036432 CP036433', 'SRR37301126', 'DRR905474', 'ERS3208922',
      'PRJEB100972', 'GWHHOSX00000000.1', 'not yet available', 'cp036432',
      'SAMN48198398', 'SAMD00093579', 'SAMN48697936, JBPYXL000000000'
    ].each do |acc|
      errors = accession_errors(database: 'nuccore', accession: acc)
      assert_not_empty(errors[:accession], "expected #{acc.inspect} to be invalid")
    end
  end

  test 'suggests the right database when an accession belongs to another' do
    errors = accession_errors(database: 'nuccore', accession: 'GCA_039803745.1')
    assert_match(/looks like an NCBI Assembly accession/, errors[:accession].first)

    errors = accession_errors(database: 'assembly', accession: 'AUEK00000000')
    assert_match(/looks like an INSDC Nucleotide accession/, errors[:accession].first)
  end

  test 'does not check the format of pending genomes' do
    errors = accession_errors(database: 'pending', accession: 'anything goes here')
    assert_empty(errors[:accession])
  end

  test 'strips leading and trailing whitespace from the accession' do
    genome = Genome.new(database: 'assembly', accession: "  GCA_000175575.2 \n")
    genome.validate
    assert_equal('GCA_000175575.2', genome.accession)
    assert_empty(genome.errors[:accession])
  end

  test 'existing genomes with legacy accessions can still be updated' do
    genome = genomes(:one)
    genome.update_columns(database: 'nuccore', accession: 'GCA_039803745.1')

    assert genome.update(auto_failed: 'Cannot find ncbi:nuccore:GCA_039803745.1')
    assert_not genome.update(accession: 'GCA_039803745.2')
  end

  test 'accepts BioSample and SRA Experiment sources, comma-separated' do
    {
      biosample: ['SAMN10878311', 'SAMEA6956417, SAMEA6939414', 'SAMD00093579'],
      sra: ['SRX1234567', 'ERX123456, DRX123456']
    }.each do |db, list|
      list.each do |acc|
        errors = accession_errors(
          database: 'pending', accession: 'x',
          source_database: db.to_s, source_accession: acc
        )
        assert_empty(errors[:source_accession], "expected #{db}:#{acc} to be valid")
      end
    end
  end

  test 'rejects sources that are not BioSamples or SRA Experiments' do
    {
      biosample: ['ERS861224', 'SRS9415155', 'PRJNA384792', 'SAMN15855652 SAMN15855653'],
      sra: ['SRR12620258', 'SRS18309842', 'SAMN10878311', 'SRP119423']
    }.each do |db, list|
      list.each do |acc|
        errors = accession_errors(
          database: 'pending', accession: 'x',
          source_database: db.to_s, source_accession: acc
        )
        assert_not_empty(errors[:source_accession], "expected #{db}:#{acc} to be invalid")
      end
    end

    errors = accession_errors(
      database: 'pending', accession: 'x',
      source_database: 'sra', source_accession: 'SAMN10878311'
    )
    assert_match(/looks like an INSDC BioSample accession/, errors[:source_accession].first)
  end

  test 'rejects unknown source databases' do
    errors = accession_errors(
      database: 'pending', accession: 'x',
      source_database: '<div>Free text</div>', source_accession: 'SAMN10878311'
    )
    assert_not_empty(errors[:source_database])
  end

  test 'accession formats can be checked without full validation' do
    genome = Genome.new(database: 'nuccore', accession: 'GCA_039803745.1')
    genome.validate_accession_formats
    assert_not_empty(genome.errors[:accession])
  end

  test 'remove_miga! skips genomes without a MiGA dataset' do
    genome = genomes(:one)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'metadata'))
      called = false
      Genome.stub(:miga_project_path, dir) do
        cli = Object.new.tap { |o| o.define_singleton_method(:launch) { |*_| nil } }
        MiGA::Cli.stub(:new, ->(*_) { called = true; cli }) do
          assert_nil genome.remove_miga!
          assert_not called, 'MiGA should not be called without a dataset'

          File.write(File.join(dir, 'metadata', "#{genome.miga_name}.json"), '{}')
          genome.remove_miga!
          assert called, 'MiGA should be called when the dataset exists'
        end
      end
    end
  end

  test 'recalculate_miga! requeues genomes without a MiGA dataset' do
    genome = genomes(:one)
    genome.update_columns(
      auto_failed: 'Cannot find ncbi:assembly:GCA_000175575',
      auto_scheduled_at: 1.day.ago
    )
    Dir.mktmpdir do |dir|
      Genome.stub(:miga_project_path, dir) do
        _out, err = capture_io { genome.recalculate_miga! }
        assert_empty err
      end
    end
    genome.reload
    assert_nil genome.auto_failed
    assert_nil genome.auto_scheduled_at
  end

  test 'orphan genomes are removed six months after their last update' do
    genome = genomes(:one)
    genome.update_column(:updated_at, Time.utc(2026, 11, 10, 12))

    assert_equal Date.new(2027, 5, 10), genome.orphan_removal_date
  end
end
