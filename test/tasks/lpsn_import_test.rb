require 'test_helper'
require 'rake'
require 'csv'

class LpsnImportTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?('lpsn:import')
    @task = Rake::Task['lpsn:import']
    @task.reenable

    # Escherichia colie is deprecated in favour of Escherichia coli
    names(:escherichia_colie).update_columns(
      redirect_id: names(:escherichia_coli).id
    )

    @dir = Dir.mktmpdir
    @csv = File.join(@dir, 'lpsn_gss.csv')
    header = %w[
      record_no genus_name sp_epithet subsp_epithet nomenclatural_type
      status authors address record_lnk
    ]
    rows = [
      # SeqCode names, bypassed
      ['1', 'Escherichia', nil, nil, '2', 'x', nil, nil, nil],
      ['2', 'Escherichia', 'coli', nil, 'DSM 1', 'x', nil, nil, nil],
      # Deprecated name, bypassed
      ['3', 'Escherichia', 'colie', nil, 'DSM 2', 'x', nil, nil, nil],
      # ICNP synonyms of bypassed names
      ['4', 'Testibacter', 'coli', nil, 'DSM 3', 'x', 'A', nil, '2'],
      ['5', 'Testibacter', 'colie', nil, 'DSM 4', 'x', 'B', nil, '3'],
      # ICNP genus typified by a bypassed SeqCode species
      ['6', 'Testibacter', nil, nil, '2', 'x', 'C', nil, nil],
      # ICNP synonym of a record missing from the file
      ['7', 'Testibacter', 'missing', nil, 'DSM 5', 'x', 'D', nil, '999']
    ]
    CSV.open(@csv, 'w') do |csv|
      csv << header
      rows.each { |row| csv << row }
    end
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test 'links synonyms and types to bypassed names without aborting' do
    _out, err = capture_io { @task.invoke(@csv) }

    coli = names(:escherichia_coli)
    assert_equal coli.id, Name.find_by(name: 'Testibacter coli').correct_name_id
    assert_equal coli.id, Name.find_by(name: 'Testibacter colie').correct_name_id
    assert_equal coli, Name.find_by(name: 'Testibacter').nomenclatural_type
    assert_nil Name.find_by(name: 'Testibacter missing').correct_name_id
    assert_match(/Correct name not in parsed names: \d+ \(999\)/, err)

    # Bypassed names are left untouched
    assert_equal 15, coli.reload.status
    assert_nil coli.authority
  end
end
