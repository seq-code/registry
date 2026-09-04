# frozen_string_literal: true

require 'application_system_test_case'

class TutorialsTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    @user = users(:contributor)
    @tutorial = Tutorial.create!(
      pipeline: 'batch', user: @user, step: 0, ongoing: true
    )

    login_as(@user, scope: :user)
  end

  teardown { Warden.test_reset! }

  test 'batch uploading a single genus' do
    family = names(:nanobdellaceae)
    type_species = names(:nanoclepta_minutus)
    visit tutorial_url(@tutorial)

    assert_text 'Step 0: Upload spreadsheet'

    upload_batch_spreadsheet('SCR_UploadBatch-Nanoclepta.xlsx')
    assert_batch_review(name: 'Nanoclepta', parent: 'Nanobdellaceae')
    create_batch_entries

    genus = Name.find_by!(name: 'Nanoclepta')
    @tutorial.reload

    assert_equal 'genus', genus.rank
    assert_equal family, genus.parent
    assert_equal type_species, genus.nomenclatural_type
    assert_equal @tutorial, genus.tutorial
    assert_equal ['Nanoclepta'], @tutorial.names.pluck(:name)

    complete_batch_tutorial
  end

  test 'batch uploading a single incertae sedis genus' do
    type_species = names(:luteria_ianthellae)
    visit tutorial_url(@tutorial)

    upload_batch_spreadsheet('SCR_UploadBatch-Luteria-Incertae_sedis.xlsx')
    incertae_sedis = 'incertae sedis (Bacteria)'
    assert_batch_review(name: 'Luteria', parent: incertae_sedis)

    create_batch_entries

    genus = Name.find_by!(name: 'Luteria')
    @tutorial.reload

    assert_equal 'genus', genus.rank
    assert_nil genus.parent
    assert_equal incertae_sedis, genus.incertae_sedis
    assert_equal type_species, genus.nomenclatural_type
    assert_equal @tutorial, genus.tutorial
    assert_equal ['Luteria'], @tutorial.names.pluck(:name)

    complete_batch_tutorial
  end

  private

  def complete_batch_tutorial
    click_button 'Continue'

    assert_current_path new_register_path(tutorial: @tutorial)
    assert_not @tutorial.reload.ongoing?
  end

  def upload_batch_spreadsheet(filename)
    attach_file(
      'Batch spreadsheet',
      Rails.root.join('test/fixtures/files', filename)
    )
    click_button 'Continue'
  end

  def assert_batch_review(name:, parent:)
    assert_text 'Step 1: Review parsed data'
    within '#batch-names-0-h' do
      assert_text name
      assert_text 'genus of'
      assert_text parent
    end
    assert_no_selector '#batch-names-1-h'

    assert_no_selector '#batch-genomes-0-h'
  end

  def create_batch_entries
    assert_difference('Name.count', 1) do
      assert_no_difference('Genome.count') do
        click_button 'Continue'
        assert_text 'Step 2: Validation list'
      end
    end
  end
end
