require 'test_helper'
require 'minitest/mock'

class TagEvaluationServiceTest < ActiveSupport::TestCase
  def proposal(slug, confidence = 'high', basis = nil, **extra)
    { 'slug' => slug, 'confidence' => confidence, 'basis' => basis }
      .merge(extra.transform_keys(&:to_s))
  end

  def result(curator:, runs:, rejected: [], rank: 'species')
    {
      'name' => 'Foo bar', 'rank' => rank, 'etymology' => 'L. masc. n. foo',
      'partial' => false, 'curator' => curator, 'rejected' => rejected,
      'runs' => runs
    }
  end

  test 'gold names are fully reviewed names with accepted tags' do
    names = TagEvaluationService.gold_names
    assert_equal(
      [names(:escherichia), names(:escherichia_colie)].sort_by(&:id),
      names.to_a
    )
    assert_equal(names.first(1), TagEvaluationService.gold_names(limit: 1).to_a)
    assert_equal(
      names.last(1),
      TagEvaluationService.gold_names(limit: 1, offset: 1).to_a
    )
    assert_empty(TagEvaluationService.gold_names(offset: 2))
    assert_equal(
      [names(:escherichia_colie)],
      TagEvaluationService.gold_names(rank: 'species').to_a
    )
  end

  test 'gold names can include names with pending proposals' do
    NameTag.create!(name: names(:escherichia_coli), tag: tags(:masculine),
                    status_int: TagEvaluationService.status_int(:accepted))

    assert_not_includes(
      TagEvaluationService.gold_names, names(:escherichia_coli)
    )
    assert_includes(
      TagEvaluationService.gold_names(include_partial: true),
      names(:escherichia_coli)
    )
  end

  test 'gold names filtered by tag include implied tags' do
    assert_equal(
      [names(:escherichia)],
      TagEvaluationService.gold_names(tag: 'commemorative').to_a
    )
    assert_equal(
      [names(:escherichia_colie)],
      TagEvaluationService.gold_names(tag: 'toponym').to_a
    )
  end

  test 'evaluate expands curator tags and keeps proposals in memory' do
    name = names(:escherichia)
    NameTag.create!(name: name, tag: tags(:toponym),
                    status_int: TagEvaluationService.status_int(:rejected))
    returned = [proposal('eponym', 'high', 'Escherich', extra: 'dropped')]

    evaluation = nil
    assert_no_difference('NameTag.count') do
      TaggingService.stub(:propose, returned) do
        evaluation = TagEvaluationService.evaluate(name, runs: 2)
      end
    end

    # The fixture only accepts eponym; its umbrella is implied
    assert_equal(%w[commemorative eponym], evaluation['curator'])
    assert_equal(%w[toponym], evaluation['rejected'])
    assert_equal(false, evaluation['partial'])
    assert_equal(2, evaluation['runs'].size)
    assert_equal(
      [{ 'slug' => 'eponym', 'confidence' => 'high', 'basis' => 'Escherich' }],
      evaluation['runs'].first
    )
  end

  test 'evaluate propagates tagging errors' do
    raiser = ->(_name) { raise(TaggingService::Error, 'boom') }
    TaggingService.stub(:propose, raiser) do
      assert_raises(TaggingService::Error) do
        TagEvaluationService.evaluate(names(:escherichia))
      end
    end
  end

  test 'compare splits tags across runs' do
    cmp = TagEvaluationService.compare(
      result(
        curator: %w[eponym masculine], rejected: %w[toponym],
        runs: [
          [proposal('eponym'), proposal('toponym', 'medium', 'Foo')],
          [proposal('eponym'), proposal('toponym', 'low', 'foo-')],
          [proposal('neuter', 'medium', 'n.')]
        ]
      )
    )

    assert_equal([{ 'slug' => 'eponym', 'count' => 2 }], cmp['concordant'])
    assert_equal(%w[masculine], cmp['curator_only'])
    toponym, neuter = cmp['proposal_only'].sort_by { |e| e['slug'] }.reverse
    assert_equal(2, toponym['count'])
    assert_equal(%w[medium low], toponym['confidences'])
    assert_equal(%w[Foo foo-], toponym['bases'])
    assert(toponym['rejected'])
    assert_equal(1, neuter['count'])
    assert_not(neuter['rejected'])
  end

  test 'metrics count every run, overall and per tag' do
    results = [
      result(
        curator: %w[commemorative eponym], rejected: %w[toponym],
        runs: [
          [proposal('commemorative'), proposal('eponym', 'medium'),
           proposal('toponym', 'low')],
          [proposal('commemorative')]
        ]
      ),
      result(curator: %w[masculine], runs: [[proposal('neuter')]])
    ]

    all = TagEvaluationService.metrics(results)
    assert_equal([3, 2, 2], all.values_at('tp', 'fp', 'fn'))
    assert_equal(0.6, all['precision'])
    assert_equal(0.6, all['recall'])
    assert_equal(1, all['rejected_hits'])
    assert_equal(
      %w[eponym masculine neuter toponym commemorative], all['per_tag'].keys
    )
    assert_equal(
      { 'tp' => 1, 'fp' => 0, 'fn' => 1, 'precision' => 1.0, 'recall' => 0.5 },
      all['per_tag']['eponym']
    )
    assert_nil(all['per_tag']['neuter']['recall'])

    high = TagEvaluationService.metrics(results, min_confidence: 'high')
    assert_equal([2, 1, 3], high.values_at('tp', 'fp', 'fn'))
    assert_equal(0, high['rejected_hits'])
  end

  test 'gender confusion compares curator and proposed genders per run' do
    results = [
      result(curator: %w[masculine eponym],
             runs: [[proposal('masculine')], [proposal('neuter')], []]),
      result(curator: %w[eponym], runs: [[proposal('feminine')]]),
      result(curator: %w[eponym], rank: 'domain',
             runs: [[proposal('feminine')]])
    ]

    assert_equal(
      { %w[masculine masculine] => 1, %w[masculine neuter] => 1,
        %w[masculine none] => 1, %w[none feminine] => 1 },
      TagEvaluationService.gender_confusion(results)
    )
  end

  test 'name report shows run counts and rejected proposals' do
    lines = TagEvaluationService.name_report(
      result(
        curator: %w[eponym neuter], rejected: %w[toponym],
        runs: [
          [proposal('neuter'), proposal('toponym', 'medium', 'Foo')],
          [proposal('neuter'), proposal('toponym', 'medium', 'Foo')],
          [proposal('eponym')]
        ]
      )
    )

    assert_equal('Foo bar (species)', lines[0])
    assert_equal('  Etymology: L. masc. n. foo', lines[1])
    assert_equal('  Concordant: eponym 1/3, neuter 2/3', lines[2])
    assert_equal('  Curator only: (none)', lines[3])
    assert_equal(
      '    toponym 2/3 (medium×2; basis: Foo) [REJECTED]', lines.last
    )
  end

  test 'summary report has the header, metrics, and gender table' do
    results = [
      result(curator: %w[masculine], runs: [[proposal('masculine')]])
    ]
    lines = TagEvaluationService.summary_report(
      results, 'Backend' => 'anthropic', 'Failures' => 0
    )

    assert_equal(['Backend: anthropic', 'Failures: 0'], lines.first(2))
    assert_includes(
      lines, 'All proposals: precision 1.000, recall 1.000 (tp 1, fp 0, fn 0)'
    )
    assert(lines.any? { |l| l.start_with?('High-confidence proposals:') })
    assert_match(/masculine\s+1\z/, lines.last)
  end
end
