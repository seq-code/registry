require 'test_helper'

class Name::QualityChecksTest < ActiveSupport::TestCase
  def evaluate(name, check)
    Name::QualityChecks::QcWarningSet.new(name).evaluate(check)
  end

  def warning(name, check)
    Name::QualityChecks::QcWarning.new(check, name: name)
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

  test 'inconsistent_parent_rank does not flag a parent one rank above' do
    name = names(:escherichia_coli)
    qc = warning(name, :inconsistent_parent_rank)

    assert_predicate(qc, :scope)
    assert_not_predicate(qc, :failure)
  end

  test 'inconsistent_parent_rank flags a parent more than one rank above' do
    name = names(:escherichia_coli).dup
    name.parent = names(:nanobdellaceae)
    qc = warning(name, :inconsistent_parent_rank)

    assert_predicate(qc, :scope)
    assert_predicate(qc, :failure)
  end

  test 'inconsistent_parent_rank flags a parent at the same rank' do
    name = names(:escherichia_coli).dup
    name.parent = names(:bacillus_subtilis)
    qc = warning(name, :inconsistent_parent_rank)

    assert_predicate(qc, :scope)
    assert_predicate(qc, :failure)
  end

  test 'inconsistent_parent_rank is out of scope without a parent rank' do
    name = names(:escherichia_coli).dup
    name.parent = names(:escherichia).dup
    name.parent.rank = nil
    qc = warning(name, :inconsistent_parent_rank)

    assert_not_predicate(qc, :scope)
  end

  test 'missing_parent flags a non-top-rank name without a placement' do
    name = names(:bacillus_subtilis)
    qc = warning(name, :missing_parent)

    assert_predicate(qc, :scope)
    assert_predicate(qc, :failure)
  end

  test 'missing_parent accepts an incertae sedis placement' do
    name = names(:luteria_ianthellae)
    Placement.create!(
      name: name, preferred: true,
      incertae_sedis: 'incertae sedis (Bacteria)',
      incertae_sedis_text: 'Its precise placement within Bacteria is unknown.'
    )
    qc = warning(name, :missing_parent)

    assert_predicate(qc, :scope)
    assert_not_predicate(qc, :failure)
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
