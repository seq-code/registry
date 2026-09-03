require 'test_helper'

class TutorialTest < ActiveSupport::TestCase
  test 'batch parses a name' do
    tutorial = upload_batch_spreadsheet('SCR_UploadBatch-Nanoclepta.xlsx')
    name = tutorial.ephemeral_names.first
    placement = name.placements.first

    assert_equal 1, tutorial.step
    assert_empty tutorial.value(:genomes)
    assert_equal 1, tutorial.value(:names).size
    assert_equal 'Nanoclepta', tutorial.value(:names).first['name']
    assert_equal 'Nanobdellaceae', tutorial.value(:names).first['parent']
    assert_nil name.parent
    assert_nil name[:incertae_sedis]
    assert_same name, placement.name
    assert_equal 'Nanobdellaceae', placement.parent.name
    assert_not_predicate placement, :incertae_sedis?
    assert_empty placement.incertae_sedis_text.to_plain_text
  end

  test 'batch parses an incertae sedis name' do
    tutorial = upload_batch_spreadsheet(
      'SCR_UploadBatch-Luteria-Incertae_sedis.xlsx'
    )
    name = tutorial.ephemeral_names.first
    placement = name.placements.first

    assert_equal 1, tutorial.step
    assert_empty tutorial.value(:genomes)
    assert_equal 1, tutorial.value(:names).size
    assert_equal 'Luteria', tutorial.value(:names).first['name']
    assert_equal(
      'incertae sedis (Bacteria)', tutorial.value(:names).first['parent']
    )
    assert_nil name.parent
    assert_nil name[:incertae_sedis]
    assert_equal names(:bacteria).name, placement.parent.name
    assert_predicate placement, :incertae_sedis?
    assert_equal(
      tutorial.value(:names).first['description'],
      placement.incertae_sedis_text.to_plain_text
    )
  end

  test 'batch creates a parent placement' do
    tutorial = upload_batch_spreadsheet('SCR_UploadBatch-Nanoclepta.xlsx')
    parent = names(:nanobdellaceae)

    assert tutorial.batch_step_01({}, users(:contributor))

    name = Name.find_by!(name: 'Nanoclepta')
    placement = name.placement

    assert_not_nil placement
    assert_predicate placement, :preferred?
    assert_equal parent, placement.parent
    assert_equal parent, name.parent
    assert_not_predicate placement, :incertae_sedis?
  end

  test 'batch updates a claimable name with a preferred placement' do
    parent = names(:nanobdellaceae)
    name = Name.create!(
      name: 'Nanoclepta', rank: 'genus', status: 5,
      created_by: users(:contributor), parent: parent
    )
    placement = name.placement
    tutorial = upload_batch_spreadsheet('SCR_UploadBatch-Nanoclepta.xlsx')

    assert_no_difference('Placement.count') do
      assert tutorial.batch_step_01({}, users(:contributor))
    end

    assert_equal placement, name.reload.placement
    assert_equal parent, name.parent
  end

  test 'batch replaces a claimable name preferred placement' do
    old_parent = Name.create!(
      name: 'Nanoarchaeaceae', rank: 'family', status: 15
    )
    name = Name.create!(
      name: 'Nanoclepta', rank: 'genus', status: 5,
      created_by: users(:contributor), parent: old_parent
    )
    old_placement = name.placement
    tutorial = upload_batch_spreadsheet('SCR_UploadBatch-Nanoclepta.xlsx')

    assert_difference('Placement.count', 1) do
      assert tutorial.batch_step_01({}, users(:contributor))
    end

    name = Name.find(name.id)
    assert_equal names(:nanobdellaceae), name.placement.parent
    assert_not old_placement.reload.preferred?
    assert_includes name.alt_placements, old_placement
  end

  test 'batch creates an incertae sedis placement' do
    tutorial = upload_batch_spreadsheet(
      'SCR_UploadBatch-Luteria-Incertae_sedis.xlsx'
    )
    explanation = tutorial.value(:names).first['description']

    assert tutorial.batch_step_01({}, users(:contributor))

    name = Name.find_by!(name: 'Luteria')
    placement = name.placement

    assert_not_nil placement
    assert_predicate placement, :preferred?
    assert_equal names(:bacteria), placement.parent
    assert_nil name.parent
    assert_predicate placement, :incertae_sedis?
    assert_equal explanation, placement.incertae_sedis_text.to_plain_text
    assert_nil name[:incertae_sedis]
  end

  test 'batch replaces a claimable name placement with incertae sedis' do
    old_parent = names(:escherichia)
    name = Name.create!(
      name: 'Luteria', rank: 'genus', status: 5,
      created_by: users(:contributor), parent: old_parent
    )
    old_placement = name.placement
    tutorial = upload_batch_spreadsheet(
      'SCR_UploadBatch-Luteria-Incertae_sedis.xlsx'
    )

    assert_difference('Placement.count', 1) do
      assert tutorial.batch_step_01({}, users(:contributor))
    end

    name = Name.find(name.id)
    assert_predicate name.placement, :incertae_sedis?
    assert_not_predicate old_placement.reload, :preferred?
    assert_includes name.alt_placements, old_placement
    assert_nil name[:incertae_sedis]
  end

  private

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
