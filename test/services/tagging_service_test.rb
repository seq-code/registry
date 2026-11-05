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
    %w[feminine neuter gender-uncertain].each do |slug|
      Tag.create!(name: slug.tr('-', ' '), slug: slug, color: '#000000')
    end
  end

  # Run TaggingService.propose for +name+ with a backend returning
  # +proposals+, so no API call is made
  def proposals_with(*proposals, name: names(:bacillus))
    backend = Class.new do
      define_method(:propose) { |_name| proposals }
    end
    TaggingService.stub(:backend, backend) do
      TaggingService.propose(name)
    end
  end

  def propose_with(*proposals)
    proposals_with(*proposals).map { |p| p['slug'] }
  end

  # Run TaggingService.propose for a name of +rank+ whose gender predicates
  # return true for the slugs in +declared+, raise for those in +raises+,
  # and return false otherwise. Returns the resulting gender proposals
  def gender_proposals_with(*proposals, rank:, declared: [], raises: [])
    name = names(:bacillus)
    stubs = { rank: rank }
    TaggingService::GENDER_PREDICATES.each do |slug, predicate|
      stubs[predicate] =
        if raises.include?(slug)
          ->(*) { raise(NoMethodError, 'no structured etymology') }
        else
          declared.include?(slug)
        end
    end
    result = with_stubs(name, stubs.to_a) do
      proposals_with(*proposals, name: name)
    end
    result.select { |p| Tag::GENDER_SLUGS.include?(p['slug']) }
  end

  def with_stubs(object, stubs, &block)
    return yield if stubs.empty?

    (method, value), *rest = stubs
    object.stub(method, value) { with_stubs(object, rest, &block) }
  end

  def proposal(slug, confidence, basis = 'foo')
    { 'slug' => slug, 'confidence' => confidence, 'basis' => basis }
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

  test 'propose replaces gender proposals with the declared gender' do
    genders = gender_proposals_with(
      proposal('masculine', 'high'), rank: 'species', declared: %w[neuter]
    )

    assert_equal(['neuter'], genders.map { |p| p['slug'] })
    assert_equal('high', genders.first['confidence'])
    assert_equal('declared in etymology', genders.first['basis'])
  end

  test 'propose adds the declared gender if the model proposed none' do
    genders = gender_proposals_with(
      proposal('toponym', 'high'), rank: 'species', declared: %w[masculine]
    )

    assert_equal(['masculine'], genders.map { |p| p['slug'] })
    assert_equal('high', genders.first['confidence'])
  end

  test 'propose assigns gender-uncertain for several declared genders' do
    genders = gender_proposals_with(
      proposal('feminine', 'high'),
      rank: 'species', declared: %w[masculine feminine]
    )

    assert_equal(['gender-uncertain'], genders.map { |p| p['slug'] })
    assert_equal('high', genders.first['confidence'])
    assert_equal(
      'declared in etymology (multiple genders)', genders.first['basis']
    )
  end

  test 'propose caps high gender proposals if no gender is declared' do
    genders =
      gender_proposals_with(proposal('masculine', 'high'), rank: 'species')

    assert_equal(['masculine'], genders.map { |p| p['slug'] })
    assert_equal('medium', genders.first['confidence'])
    assert_equal(true, genders.first['capped'])
  end

  test 'propose leaves lower gender proposals if no gender is declared' do
    genders =
      gender_proposals_with(proposal('feminine', 'low'), rank: 'species')

    assert_equal(['feminine'], genders.map { |p| p['slug'] })
    assert_equal('low', genders.first['confidence'])
    assert_nil(genders.first['capped'])
  end

  test 'propose drops gender proposals for ranks without gender' do
    genders = gender_proposals_with(
      proposal('feminine', 'high'), rank: 'family', declared: %w[feminine]
    )

    assert_empty(genders)
  end

  test 'propose treats a raising gender predicate as false' do
    genders = gender_proposals_with(
      proposal('masculine', 'high'),
      rank: 'species', declared: %w[neuter], raises: %w[masculine feminine]
    )

    assert_equal(['neuter'], genders.map { |p| p['slug'] })
    assert_equal('high', genders.first['confidence'])
  end
end
