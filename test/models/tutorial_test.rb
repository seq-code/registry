require 'test_helper'

class TutorialTest < ActiveSupport::TestCase
  test 'batch parses a name from a spreadsheet' do
    tutorial = upload_batch_spreadsheet('SCR_UploadBatch-Nanoclepta.xlsx')

    assert_equal 1, tutorial.step
    assert_empty tutorial.value(:genomes)
    assert_equal 1, tutorial.value(:names).size
    assert_equal 'Nanoclepta', tutorial.value(:names).first['name']
    assert_equal 'Nanobdellaceae', tutorial.value(:names).first['parent']
  end

  test 'batch parses an incertae sedis name from a spreadsheet' do
    tutorial = upload_batch_spreadsheet(
      'SCR_UploadBatch-Luteria-Incertae_sedis.xlsx'
    )

    assert_equal 1, tutorial.step
    assert_empty tutorial.value(:genomes)
    assert_equal 1, tutorial.value(:names).size
    assert_equal 'Luteria', tutorial.value(:names).first['name']
    assert_equal(
      'incertae sedis (Bacteria)', tutorial.value(:names).first['parent']
    )
  end

  test 'batch creates a parent placement' do
    parent = Name.create!(
      name: 'Nanobdellaceae', rank: 'family', status: 15
    )
    placement = create_batch_placement(
      name: 'Nanoclepta', rank: 'genus',
      description: 'A genus of ectosymbiotic archaea.', parent: parent.name
    )

    assert_equal parent, placement.parent
    assert_nil placement.incertae_sedis
  end

  test 'batch creates an incertae sedis placement' do
    explanation = 'The genus cannot currently be assigned to a family.'
    placement = create_batch_placement(
      name: 'Luteria', rank: 'genus', description: explanation,
      parent: 'incertae sedis (Bacteria)'
    )

    assert_nil placement.parent
    assert_equal 'incertae sedis (Bacteria)', placement.incertae_sedis
    assert_equal explanation, placement.incertae_sedis_text.to_plain_text
  end

  private

  def create_batch_placement(name:, **attributes)
    tutorial = Tutorial.create!(
      pipeline: 'batch', user: users(:contributor), step: 1,
      data: {
        names: [attributes.merge(name: name)], genomes: []
      }.to_json
    )

    assert tutorial.batch_step_01({}, users(:contributor))

    placement = Name.find_by!(name: name).placement
    assert_not_nil placement
    assert_predicate placement, :preferred?
    placement
  end

  def upload_batch_spreadsheet(filename)
    tutorial = Tutorial.create!(
      pipeline: 'batch', user: users(:contributor), step: 0, ongoing: true
    )
    File.open(Rails.root.join('test/fixtures/files', filename)) do |file|
      assert tutorial.batch_step_00({ file: file }, users(:contributor))
    end
    tutorial
  end
end
