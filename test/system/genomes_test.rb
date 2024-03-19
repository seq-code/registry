require 'application_system_test_case'

class GenomesTest < ApplicationSystemTestCase
  setup do
    @genome = genomes(:one)
  end

  test 'visiting the index' do
    visit genomes_url
    assert_selector 'h1', text: 'Genomes'
  end

  test 'creating a Genome' do
    visit genomes_url
    click_on 'New Genome'

    fill_in 'Accession', with: @genome.accession
    check 'Auto check' if @genome.auto_check
    fill_in 'Completeness', with: @genome.completeness
    fill_in 'Contamination', with: @genome.contamination
    fill_in 'Database', with: @genome.database
    fill_in 'Gc content', with: @genome.gc_content
    fill_in 'Most complete 16s', with: @genome.most_complete_16s
    fill_in 'Most complete 23s', with: @genome.most_complete_23s
    fill_in 'Number of 16s', with: @genome.number_of_16s
    fill_in 'Number of 23s', with: @genome.number_of_23s
    fill_in 'Number of trnas', with: @genome.number_of_trnas
    fill_in 'Seq depth', with: @genome.seq_depth
    fill_in 'Type', with: @genome.type
    fill_in 'Updated by', with: @genome.updated_by
    click_on 'Create Genome'

    assert_text 'Genome was successfully created'
    click_on 'Back'
  end

  test 'updating a Genome' do
    visit genomes_url
    click_on 'Edit', match: :first

    fill_in 'Accession', with: @genome.accession
    check 'Auto check' if @genome.auto_check
    fill_in 'Completeness', with: @genome.completeness
    fill_in 'Contamination', with: @genome.contamination
    fill_in 'Database', with: @genome.database
    fill_in 'Gc content', with: @genome.gc_content
    fill_in 'Most complete 16s', with: @genome.most_complete_16s
    fill_in 'Most complete 23s', with: @genome.most_complete_23s
    fill_in 'Number of 16s', with: @genome.number_of_16s
    fill_in 'Number of 23s', with: @genome.number_of_23s
    fill_in 'Number of trnas', with: @genome.number_of_trnas
    fill_in 'Seq depth', with: @genome.seq_depth
    fill_in 'Type', with: @genome.type
    fill_in 'Updated by', with: @genome.updated_by
    click_on 'Update Genome'

    assert_text 'Genome was successfully updated'
    click_on 'Back'
  end

  test 'destroying a Genome' do
    visit genomes_url
    page.accept_confirm do
      click_on 'Destroy', match: :first
    end

    assert_text 'Genome was successfully destroyed'
  end
end
