require 'test_helper'

class GenomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @genome = genomes(:one)
    @genome_with_locations = genomes(:with_locations)
  end

  test 'sample_map renders a map when locations are available' do
    get sample_map_genome_path(@genome_with_locations)

    assert_response :success
    assert_match(/<!DOCTYPE html>/i, response.body)
    assert_select 'div#map[style*="800px"]'
    assert_select 'script[type=module]', text: /maplibre-gl\.mjs/
  end

  test 'sample_map as content skips the layout but still loads maplibre-gl' do
    get sample_map_genome_path(@genome_with_locations, content: true)

    assert_response :success
    assert_no_match(/<!DOCTYPE html>/i, response.body)
    assert_select 'div#map[style*="400px"]'
    assert_select 'script[type=module]', text: /maplibre-gl\.mjs/
  end

  test 'sample_map shows a warning when no locations are available' do
    get sample_map_genome_path(@genome)

    assert_response :success
    assert_select 'div#map', count: 0
    assert_select '.alert', text: /no available samples/
  end
end
