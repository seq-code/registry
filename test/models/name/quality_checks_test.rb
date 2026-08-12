require 'test_helper'

class Name::QualityChecksTest < ActiveSupport::TestCase
  def evaluate(name, check)
    Name::QualityChecks::QcWarningSet.new(name).evaluate(check)
  end

  test 'malformed_subspecies_name does not raise and flags a malformed name' do
    name = Name.new(
      name: 'Testimonas exampleensis testus', rank: 'subspecies'
    )

    assert(evaluate(name, :malformed_subspecies_name))
  end

  test 'malformed_subspecies_name does not flag a well-formed name' do
    name = Name.new(
      name: 'Testimonas exampleensis subsp. testus', rank: 'subspecies'
    )

    assert_not(evaluate(name, :malformed_subspecies_name))
  end

  test 'malformed_subspecies_name is out of scope for non-subspecies ranks' do
    name = Name.new(name: 'Testimonas exampleensis', rank: 'species')

    assert_not(evaluate(name, :malformed_subspecies_name))
  end

  test 'inconsistent_language flags a non-Latin etymology' do
    name = names(:escherichia_coli)
    name.define_singleton_method(:etymology?) { true }
    name.define_singleton_method(:latin?) { false }

    assert(evaluate(name, :inconsistent_language))
  end

  test 'inconsistent_language is out of scope without an etymology' do
    name = names(:escherichia_coli)
    name.define_singleton_method(:etymology?) { false }

    assert_not(evaluate(name, :inconsistent_language))
  end

  test 'binary_name_above_species flags a multi-word genus name' do
    name = Name.new(name: 'Testimonas exampleensis', rank: 'genus')

    assert(evaluate(name, :binary_name_above_species))
  end

  test 'binary_name_above_species is out of scope at or below species' do
    name = Name.new(name: 'Testimonas exampleensis', rank: 'species')

    assert_not(evaluate(name, :binary_name_above_species))
  end
end
