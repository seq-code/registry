require 'test_helper'

class GenomesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

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

  test 'anonymous visitors cannot edit or update genomes without names' do
    assert_empty @genome.names
    @genome.update_columns(source_database: 'biosample', source_accession: 'SAMN00000001')

    get edit_genome_path(@genome)
    assert_redirected_to root_path

    patch genome_path(@genome), params: {
      genome: { source_database: "sra0'XOR(if(now()=sysdate(),sleep(15),0))XOR'Z" }
    }
    assert_redirected_to root_path
    assert_equal 'biosample', @genome.reload.source_database
  end

  test 'signed-in users can still update genomes without names' do
    sign_in(users(:contributor))

    patch genome_path(@genome), params: { genome: { gc_content: 55.5 } }
    assert_equal 55.5, @genome.reload.gc_content
    assert_equal users(:contributor), @genome.updated_by
  end

  test 'orphan genomes show when they will be removed' do
    genome = Genome.create!(database: 'assembly', accession: 'GCA_000175575.2')
    genome.update_column(:updated_at, Time.utc(2026, 11, 10, 12))

    get genome_path(genome)

    assert_response :success
    assert_select '.alert-warning', /removed from the database after\s+May 10, 2027\s+\(6 months after its last update\)/
  end
end
