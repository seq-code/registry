require 'test_helper'
require 'rake'

class GenomesFixAccessionsTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?('genomes:fix_accessions')
    @task = Rake::Task['genomes:fix_accessions']

    # Don't touch any real MiGA project when requeueing
    Genome.class_eval do
      alias_method :original_remove_miga!, :remove_miga!
      define_method(:remove_miga!) { nil }
    end

    failed = ->(g) { "Cannot find ncbi:#{g[0]}:#{g[1]}" }
    @genomes = {
      requeue:   ['assembly', 'GCA_000175575', failed],
      to_asm:    ['nuccore', 'GCA_039803745.1', failed],
      to_nuc:    ['assembly', 'AUEK00000000', nil],
      conflict:  ['nuccore', 'GCA_016751895.1', failed],
      malformed: ['assembly', 'ASM1081187v1', failed],
      bypassed:  ['assembly', 'GCA_000175576.1', 'Genome processing bypassed: Low quality'],
      orphan:    ['nuccore', 'GCA_000175577.1', failed]
    }.map do |key, (db, acc, fail)|
      genome = Genome.new(
        database: db, accession: acc,
        auto_failed: fail.respond_to?(:call) ? fail.call([db, acc]) : fail,
        auto_scheduled_at: 1.day.ago, auto_check: key == :to_nuc
      )
      genome.save(validate: false) # Legacy data predates the format checks
      [key, genome]
    end.to_h

    # Correct twin of the conflicting genome, entered later by the user
    Genome.new(database: 'assembly', accession: 'GCA_016751895.1')
          .save(validate: false)

    names = %i[
      escherichia_coli bacillus_subtilis nanoclepta_minutus luteria_ianthellae
      escherichia bacillus
    ]
    (@genomes.keys - [:orphan]).zip(names).each do |key, name|
      names(name).update_columns(
        nomenclatural_type_type: 'Genome',
        nomenclatural_type_id: @genomes[key].id
      )
    end
  end

  teardown do
    @task.reenable
    Genome.class_eval do
      alias_method :remove_miga!, :original_remove_miga!
      remove_method :original_remove_miga!
    end
    ENV.delete('APPLY')
  end

  def run_task(apply: false)
    ENV['APPLY'] = '1' if apply
    _out, err = capture_io { @task.invoke }
    @genomes.each_value(&:reload)
    err
  end

  test 'dry run reports changes without applying them' do
    err = run_task

    assert_match(/dry run/, err)
    assert_match(/#{@genomes[:to_asm].miga_name} .*nuccore:GCA_039803745.1 -> assembly \(requeued\)/, err)
    assert_match(/Would do: 2 moved, 2 requeued, 1 conflicts, 1 malformed/, err)
    assert_equal 'nuccore', @genomes[:to_asm].database
    assert_not_nil @genomes[:requeue].auto_failed
  end

  test 'applies moves and requeues failed downloads' do
    err = run_task(apply: true)

    assert_match(/Done: 2 moved, 2 requeued, 1 conflicts, 1 malformed/, err)

    # Valid accession, failed download: requeued
    assert_nil @genomes[:requeue].auto_failed
    assert_nil @genomes[:requeue].auto_scheduled_at

    # Wrong database, failed download: moved and requeued
    assert_equal 'assembly', @genomes[:to_asm].database
    assert_nil @genomes[:to_asm].auto_failed

    # Wrong database, downloaded fine: moved, MiGA results kept
    assert_equal 'nuccore', @genomes[:to_nuc].database
    assert @genomes[:to_nuc].auto_check
    assert_not_nil @genomes[:to_nuc].auto_scheduled_at
  end

  test 'leaves conflicts, malformed, bypassed, and orphan genomes alone' do
    err = run_task(apply: true)

    assert_match(/\? .*nuccore:GCA_016751895.1 also exists as assembly/, err)
    assert_match(/\? .*assembly:ASM1081187v1 is malformed/, err)
    %i[conflict malformed bypassed orphan].each do |key|
      genome = @genomes[key]
      assert_not_nil genome.auto_failed, "#{key} should not be requeued"
    end
    assert_equal 'nuccore', @genomes[:conflict].database
    assert_equal 'nuccore', @genomes[:orphan].database
    assert_no_match(/#{@genomes[:orphan].miga_name}\b/, err)
  end
end
