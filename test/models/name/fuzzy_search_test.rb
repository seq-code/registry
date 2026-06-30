require 'test_helper'

class Name::FuzzySearchTest < ActiveSupport::TestCase
  test 'finds similar names by similarity' do
    matches = Name.fuzzy_search('Escherichia coli').to_a

    assert_equal names(:escherichia_coli), matches.first
    assert_equal 1.0, matches.first.score
  end

  test 'uses all valid names by default' do
    matches = Name.fuzzy_search('Escherichia colie', threshold: 0.5).to_a

    assert_includes matches, names(:escherichia_coli)
    assert_not_includes matches, names(:escherichia_colie)
  end

  test 'supports levenshtein searches' do
    matches = Name.fuzzy_search(
      'Bacillus subtiliss', method: :levenshtein, threshold: 1
    ).to_a

    assert_equal [names(:bacillus_subtilis)], matches
    assert_equal 1, matches.first.score
  end

  test 'supports genus selections' do
    matches = Name.fuzzy_search(
      'Bacilus',
      method: :levenshtein,
      threshold: 2,
      selection: :valid_genera
    ).to_a

    assert_equal [names(:bacillus)], matches
  end

  test 'limits matches' do
    matches = Name.fuzzy_search(
      'Escherichia',
      threshold: 0,
      limit: 1
    ).to_a

    assert_equal 1, matches.size
  end

  test 'raises for unsupported methods' do
    assert_raises(ArgumentError) do
      Name.fuzzy_search('Escherichia coli', method: :unknown).to_a
    end
  end
end
