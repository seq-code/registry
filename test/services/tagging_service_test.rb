require 'test_helper'
require 'minitest/mock'

class TaggingServiceTest < ActiveSupport::TestCase
  setup do
    generic = "bacter\nbacterium\nmonas\n"
    trait = Tag.create!(name: 'trait', slug: 'trait', color: '#000000',
                        excluded_bases: generic)
    Tag.create!(name: 'phenonym', slug: 'phenonym', color: '#000000',
                parent: trait, excluded_bases: generic)
    Tag.create!(name: 'chemonym', slug: 'chemonym', color: '#000000',
                parent: trait)
    tags(:masculine).update!(explicit_basis_pattern: '\bmasc\.')
    Tag.create!(name: 'feminine', slug: 'feminine', color: '#000000',
                explicit_basis_pattern: '\bfem\.')
  end

  # Run TaggingService.propose with a backend returning +proposals+, so no
  # API call is made
  def proposals_with(*proposals)
    backend = Class.new do
      define_method(:propose) { |_name| proposals }
    end
    TaggingService.stub(:backend, backend) do
      TaggingService.propose(names(:bacillus))
    end
  end

  def propose_with(*proposals)
    proposals_with(*proposals).map { |p| p['slug'] }
  end

  # The single resulting proposal for +slug+ at +confidence+ with +basis+
  def proposal_for(slug, confidence, basis)
    proposals_with(
      { 'slug' => slug, 'confidence' => confidence, 'basis' => basis }
    ).find { |p| p['slug'] == slug }
  end

  test 'excluded_bases_list normalizes the terms' do
    tag = Tag.new(excluded_bases: " -Bacter\n\nMonas.\r\nbacter\n")

    assert_equal(%w[bacter monas], tag.excluded_bases_list)
  end

  test 'propose drops proposals based on an excluded basis' do
    slugs = propose_with(
      { 'slug' => 'phenonym', 'confidence' => 'high', 'basis' => 'bacter' }
    )

    # Dropped before expansion, so no trait is implied either
    assert_empty(slugs)
  end

  test 'propose normalizes the basis before matching exclusions' do
    slugs = propose_with(
      { 'slug' => 'phenonym', 'confidence' => 'high', 'basis' => '-Bacter' }
    )

    assert_empty(slugs)
  end

  test 'propose keeps proposals with a specific basis' do
    slugs = propose_with(
      { 'slug' => 'phenonym', 'confidence' => 'high', 'basis' => 'thrix' }
    )

    assert_equal(%w[phenonym trait], slugs)
  end

  test 'propose keeps proposals of tags without exclusions' do
    slugs = propose_with(
      { 'slug' => 'chemonym', 'confidence' => 'high', 'basis' => 'bacter' }
    )

    assert_equal(%w[chemonym trait], slugs)
  end

  test 'propose keeps high confidence when the basis is explicit' do
    proposal = proposal_for('masculine', 'high', 'N.L. masc. n. Foo')

    assert_equal('high', proposal['confidence'])
    assert_nil(proposal['capped'])
  end

  test 'propose caps high confidence when the basis is not explicit' do
    proposal = proposal_for('masculine', 'high', 'camponoti')

    assert_equal('medium', proposal['confidence'])
    assert_equal(true, proposal['capped'])
  end

  test 'propose caps high confidence when the basis is blank' do
    proposal = proposal_for('masculine', 'high', '')

    assert_equal('medium', proposal['confidence'])
    assert_equal(true, proposal['capped'])
  end

  test 'propose leaves lower confidences uncapped' do
    proposal = proposal_for('masculine', 'low', 'camponoti')

    assert_equal('low', proposal['confidence'])
    assert_nil(proposal['capped'])
  end

  test 'propose requires the explicit marker of the same tag' do
    proposal = proposal_for('feminine', 'high', 'masc. adj.')

    assert_equal('medium', proposal['confidence'])
    assert_equal(true, proposal['capped'])
  end

  test 'propose does not cap tags without a pattern' do
    proposal = proposal_for('toponym', 'high', 'Svalbard')

    assert_equal('high', proposal['confidence'])
    assert_nil(proposal['capped'])
  end
end
