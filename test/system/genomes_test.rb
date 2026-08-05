require 'application_system_test_case'

class GenomesTest < ApplicationSystemTestCase
  setup do
    @genome = genomes(:one)
    @genome_with_locations = genomes(:with_locations)
  end

  test 'sample_map page renders a working map' do
    visit sample_map_genome_path(@genome_with_locations)

    assert_selector('#map canvas')
  end

  test 'sample map modal on the genome page renders a working map' do
    visit genome_path(@genome_with_locations)

    click_link('View map of sampling locations')

    within('.modal.show') do
      assert_selector('#map canvas')
    end
  end
end
