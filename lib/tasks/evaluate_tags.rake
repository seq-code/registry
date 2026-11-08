namespace :tags do
  desc <<~DESC
    Evaluate the configured tagging backend against curator decisions.
    Uses names with at least one accepted tag and no pending proposals, in
    order of ID, comparing the proposals of TaggingService.propose with the
    accepted tags (expanded with the tags they imply). Never writes to the
    database.

    Options (set as ENV vars):
      LIMIT=50       evaluate at most N names (default: 50; 0 for all)
      OFFSET=100     skip the first N names before applying LIMIT (default: 0)
      RANK=genus     only evaluate names of this rank
      TAG=eponym     only evaluate names whose curator tags include this slug
      INCLUDE_PARTIAL=1
                     also evaluate names with pending proposals (flagged as
                     partial)
      RUNS=3         query the backend N times per name (default: 1)
      OUTPUT=path    also write the full results as JSON
  DESC
  task evaluate: :environment do
    limit  = (ENV['LIMIT'].presence || 50).to_i
    offset = ENV['OFFSET'].to_i
    abort 'OFFSET must not be negative' if offset.negative?
    runs   = (ENV['RUNS'].presence || 1).to_i
    abort 'RUNS must be at least 1' if runs < 1
    if ENV['TAG'].present? && !Tag.exists?(slug: ENV['TAG'])
      abort "Unknown tag: #{ENV['TAG']}"
    end

    names = TagEvaluationService.gold_names(
      limit: limit, offset: offset, rank: ENV['RANK'], tag: ENV['TAG'],
      include_partial: ENV['INCLUDE_PARTIAL'] == '1'
    ).to_a
    backend = TaggingService.backend
    header = {
      'Backend' => Rails.configuration.tagging_backend,
      'Model' =>
        backend.const_defined?(:MODEL) ? backend.const_get(:MODEL) : 'n/a',
      'Timestamp' => Time.now.utc.iso8601,
      'Names' => names.size,
      'Runs' => runs
    }
    results = []
    failures = []

    puts "Evaluating #{names.size} names, #{runs} run(s) each..."
    TaggingService.reset_usage
    puts
    ActiveRecord::Base.while_preventing_writes do
      names.each do |name|
        result = TagEvaluationService.evaluate(name, runs: runs)
        results << result
        puts TagEvaluationService.name_report(result)
        puts
      rescue TaggingService::Error => e
        puts "ERROR #{name.name}: #{e.message}"
        puts
        failures << { 'id' => name.id, 'name' => name.name,
                      'error' => e.message }
      end
    end

    header['Failures'] = failures.size
    puts TagEvaluationService.summary_report(results, header)
    puts
    puts TaggingService.usage_summary

    if ENV['OUTPUT'].present?
      File.write(
        ENV['OUTPUT'],
        JSON.pretty_generate(
          'meta' => header, 'usage' => TaggingService.usage,
          'results' => results, 'failures' => failures
        )
      )
      puts
      puts "Results written to #{ENV['OUTPUT']}"
    end
  end
end
