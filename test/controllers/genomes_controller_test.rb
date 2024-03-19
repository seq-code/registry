require 'test_helper'

class GenomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @genome = genomes(:one)
  end

  test 'should get index' do
    get genomes_url
    assert_response :success
  end

  test 'should get new' do
    get new_genome_url
    assert_response :success
  end

  test 'should create genome' do
    assert_difference('Genome.count') do
      post genomes_url, params: { genome: { accession: @genome.accession, auto_check: @genome.auto_check, completeness: @genome.completeness, contamination: @genome.contamination, database: @genome.database, gc_content: @genome.gc_content, most_complete_16s: @genome.most_complete_16s, most_complete_23s: @genome.most_complete_23s, number_of_16s: @genome.number_of_16s, number_of_23s: @genome.number_of_23s, number_of_trnas: @genome.number_of_trnas, seq_depth: @genome.seq_depth, type: @genome.type, updated_by: @genome.updated_by } }
    end

    assert_redirected_to genome_url(Genome.last)
  end

  test 'should show genome' do
    get genome_url(@genome)
    assert_response :success
  end

  test 'should get edit' do
    get edit_genome_url(@genome)
    assert_response :success
  end

  test 'should update genome' do
    patch genome_url(@genome), params: { genome: { accession: @genome.accession, auto_check: @genome.auto_check, completeness: @genome.completeness, contamination: @genome.contamination, database: @genome.database, gc_content: @genome.gc_content, most_complete_16s: @genome.most_complete_16s, most_complete_23s: @genome.most_complete_23s, number_of_16s: @genome.number_of_16s, number_of_23s: @genome.number_of_23s, number_of_trnas: @genome.number_of_trnas, seq_depth: @genome.seq_depth, type: @genome.type, updated_by: @genome.updated_by } }
    assert_redirected_to genome_url(@genome)
  end

  test 'should destroy genome' do
    assert_difference('Genome.count', -1) do
      delete genome_url(@genome)
    end

    assert_redirected_to genomes_url
  end
end
