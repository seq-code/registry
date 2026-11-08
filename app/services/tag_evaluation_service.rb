# Compare the proposals of the tagging backend (TaggingService.propose)
# against curator decisions on fully reviewed names. Nothing is written to
# the database: proposals are only kept in memory. See the tags:evaluate task
#
# Each evaluated name is represented as a Hash with String keys (so it can
# be dumped as JSON as is):
#   'id', 'name', 'rank', 'etymology'
#   'partial'  => true if the name still has proposed NameTags
#   'curator'  => slugs of the accepted tags, expanded with the tags they
#                 imply (as accepting a tag does; see Tag.implied_closure)
#   'rejected' => slugs of the tags explicitly rejected for the name
#   'runs'     => one Array of proposals per run, as returned by
#                 TaggingService.propose (already expanded by Tag.expand)
class TagEvaluationService
  extend TaggingService::Helpers

  # Keys of each proposal kept in the results
  PROPOSAL_KEYS = %w[slug confidence basis direct implied_by capped].freeze

  class << self
    def status_int(status)
      NameTag.status.index(status)
    end

    # Names with at least one accepted tag and, unless +include_partial+, no
    # proposed tags left, in order of ID, skipping the first +offset+. If
    # +tag+ (a slug) is given, only names whose curator set includes it,
    # directly or implied
    def gold_names(
      limit: nil, offset: 0, rank: nil, tag: nil, include_partial: false
    )
      accepted = NameTag.where(status_int: status_int(:accepted))
      scope = Name.order(:id)
      scope = scope.where(rank: rank) if rank.present?
      unless include_partial
        proposed = NameTag.where(status_int: status_int(:proposed))
        scope = scope.where.not(id: proposed.select(:name_id))
      end
      if tag.present?
        tag_id = Tag.find_by!(slug: tag).id
        implying = Tag.implied_closure(Tag.pluck(:id))[tag_id] || []
        accepted = accepted.where(tag_id: [tag_id] + implying)
      end
      scope = scope.where(id: accepted.select(:name_id)).offset(offset)
      limit.to_i.positive? ? scope.limit(limit) : scope
    end

    # Evaluation Hash for +name+ (see the class documentation), calling
    # TaggingService.propose +runs+ times. Raises TaggingService::Error if
    # any of the calls fails
    def evaluate(name, runs: 1)
      result = curator_decisions(name)
      result['runs'] = Array.new(runs) do
        TaggingService.propose(name).map { |p| p.slice(*PROPOSAL_KEYS) }
      end
      result
    end

    def curator_decisions(name)
      name_tags = name.name_tags.to_a
      slugs = Tag.pluck(:id, :slug).to_h
      accepted = name_tags.select(&:accepted?).map(&:tag_id)
      expanded = accepted | Tag.implied_closure(accepted).keys
      {
        'id' => name.id,
        'name' => name.name,
        'rank' => name.rank,
        'etymology' => etymology_text(name),
        'partial' => name_tags.any?(&:proposed?),
        'curator' => slugs.values_at(*expanded).compact.sort,
        'rejected' =>
          slugs.values_at(*name_tags.select(&:rejected?).map(&:tag_id))
               .compact.sort
      }
    end

    # Per-tag comparison of the runs of +result+ against its curator set:
    #   'concordant'    => [{ 'slug', 'count' }] for curator tags proposed in
    #                      at least one run ('count' runs)
    #   'curator_only'  => [slugs] of curator tags never proposed
    #   'proposal_only' => [{ 'slug', 'count', 'confidences', 'bases',
    #                      'implied_by', 'rejected' }] for the other proposed
    #                      tags
    def compare(result)
      proposals = Hash.new { |h, k| h[k] = [] }
      result['runs'].each do |run|
        run.uniq { |p| p['slug'] }.each { |p| proposals[p['slug']] << p }
      end
      curator = result['curator']
      proposed = proposals.keys.sort
      {
        'concordant' => (curator & proposed).map do |slug|
          { 'slug' => slug, 'count' => proposals[slug].size }
        end,
        'curator_only' => curator - proposed,
        'proposal_only' => (proposed - curator).map do |slug|
          list = proposals[slug]
          {
            'slug' => slug, 'count' => list.size,
            'confidences' => list.map { |p| p['confidence'] },
            'bases' => list.map { |p| p['basis'] }.compact_blank.uniq,
            'implied_by' => list.flat_map { |p| p['implied_by'] || [] }.uniq,
            'rejected' => result['rejected'].include?(slug)
          }
        end
      }
    end

    # Precision and recall over all runs of +results+ (each run counts as an
    # instance), considering only proposals at or above +min_confidence+:
    #   'tp', 'fp', 'fn', 'precision', 'recall' (nil when undefined)
    #   'rejected_hits' => false positives on a curator-rejected tag
    #   'per_tag' => { slug => { 'tp', 'fp', 'fn', 'precision', 'recall' } },
    #                sorted by number of errors (fp + fn), most first
    def metrics(results, min_confidence: nil)
      totals = counts.merge('rejected_hits' => 0)
      per_tag = Hash.new { |h, k| h[k] = counts }
      each_run(results) do |result, run|
        proposed = run.select { |p| confident?(p, min_confidence) }
                      .map { |p| p['slug'] }.uniq
        curator = result['curator']
        { 'tp' => proposed & curator, 'fp' => proposed - curator,
          'fn' => curator - proposed }.each do |kind, slugs|
          totals[kind] += slugs.size
          slugs.each { |slug| per_tag[slug][kind] += 1 }
        end
        totals['rejected_hits'] += (proposed & result['rejected']).size
      end
      per_tag = per_tag.sort_by { |slug, c| [-(c['fp'] + c['fn']), slug] }
      with_rates(totals).merge(
        'per_tag' => per_tag.to_h { |slug, c| [slug, with_rates(c)] }
      )
    end

    # Curator gender vs. proposed gender for every run of the +results+ of
    # ranks with grammatical gender, as { [curator, proposed] => count }.
    # Each side is a gender slug, several joined by '+', or 'none'
    def gender_confusion(results)
      matrix = Hash.new(0)
      gender_ranks = TaggingService::Helpers::GENDER_RANKS
      each_run(results) do |result, run|
        next unless gender_ranks.include?(result['rank'])

        curator = gender_label(result['curator'])
        matrix[[curator, gender_label(run.map { |p| p['slug'] })]] += 1
      end
      matrix
    end

    # Lines describing a single evaluated +result+
    def name_report(result)
      runs = result['runs'].size
      count = ->(entry) { runs > 1 ? " #{entry['count']}/#{runs}" : '' }
      cmp = compare(result)
      lines = ["#{result['name']} (#{result['rank']})" \
               "#{' [partial]' if result['partial']}"]
      lines << "  Etymology: #{result['etymology'] || '(none)'}"
      lines << '  Concordant: ' +
               list(cmp['concordant'].map { |e| "#{e['slug']}#{count[e]}" })
      lines << "  Curator only: #{list(cmp['curator_only'])}"
      lines << "  Proposal only:#{' (none)' if cmp['proposal_only'].empty?}"
      cmp['proposal_only'].each do |e|
        details = [e['confidences'].tally.map { |c, n| n > 1 ? "#{c}×#{n}" : c }
                                   .join(', ')]
        details << "basis: #{e['bases'].join(' | ')}" if e['bases'].any?
        if e['implied_by'].any?
          details << "implied by: #{e['implied_by'].join(', ')}"
        end
        lines << "    #{e['slug']}#{count[e]} (#{details.join('; ')})" \
                 "#{' [REJECTED]' if e['rejected']}"
      end
      lines
    end

    # Lines summarizing +results+, starting with the entries of +header+
    def summary_report(results, header)
      lines = header.map { |key, value| "#{key}: #{value}" }
      { 'All proposals' => nil, 'High-confidence proposals' => 'high' }
        .each do |title, min_confidence|
        m = metrics(results, min_confidence: min_confidence)
        lines << ''
        lines << "#{title}: #{rates_line(m)}"
        lines << "  Proposals on curator-rejected tags: #{m['rejected_hits']}"
        m['per_tag'].each do |slug, c|
          lines << format('  %-20s %s', slug, rates_line(c))
        end
      end
      lines << ''
      lines << 'Gender (rows: curator, columns: proposed; one count per run)'
      lines.concat(confusion_table(gender_confusion(results)))
    end

    private

    def counts
      { 'tp' => 0, 'fp' => 0, 'fn' => 0 }
    end

    def each_run(results)
      results.each do |result|
        result['runs'].each { |run| yield(result, run) }
      end
    end

    def confident?(proposal, min_confidence)
      return true if min_confidence.nil?

      levels = Tag::CONFIDENCE_LEVELS
      levels.index(proposal['confidence']).to_i >= levels.index(min_confidence)
    end

    def with_rates(c)
      c.merge(
        'precision' => ratio(c['tp'], c['tp'] + c['fp']),
        'recall' => ratio(c['tp'], c['tp'] + c['fn'])
      )
    end

    def ratio(numerator, denominator)
      denominator.zero? ? nil : numerator.fdiv(denominator).round(3)
    end

    def gender_label(slugs)
      genders = Tag::GENDER_SLUGS & slugs
      genders.empty? ? 'none' : genders.join('+')
    end

    def list(items)
      items.empty? ? '(none)' : items.join(', ')
    end

    def rates_line(c)
      rate = ->(value) { value.nil? ? '  n/a' : format('%.3f', value) }
      "precision #{rate[c['precision']]}, recall #{rate[c['recall']]} " \
        "(tp #{c['tp']}, fp #{c['fp']}, fn #{c['fn']})"
    end

    def confusion_table(matrix)
      return ['  (no names of ranks with grammatical gender)'] if matrix.empty?

      labels = (Tag::GENDER_SLUGS + ['none'] + matrix.keys.flatten).uniq
      rows = labels & matrix.keys.map(&:first)
      cols = labels & matrix.keys.map(&:last)
      width = (rows + cols).map(&:size).max
      cell = ->(text) { text.to_s.rjust(width) }
      [' ' * (width + 3) + cols.map(&cell).join(' ')] +
        rows.map do |row|
          "  #{row.ljust(width)} " +
            cols.map { |col| cell[matrix[[row, col]]] }.join(' ')
        end
    end
  end
end
