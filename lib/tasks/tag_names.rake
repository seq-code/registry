namespace :tags do
  desc <<~DESC
    Propose tags for untagged names using the configured tagging backend.
    Only processes genera, species, and subspecies with no existing NameTag
    (of any status).
    Creates NameTag records with status: proposed, proposed_by: "llm".
    Names are processed in order of ID, so OFFSET/LIMIT windows are
    reproducible. Note that names with any NameTag are excluded, so a run
    without DRY_RUN shifts later offsets: windows are only stable between dry
    runs or when no proposals have been written.

    Options (set as ENV vars):
      LIMIT=50       process at most N names (default: all)
      OFFSET=100     skip the first N names before applying LIMIT (default: 0)
      DRY_RUN=1      print proposals without writing to the database
      RANK=genus     only process names of this rank (genus, species, or
                     subspecies)
      MIN_CONFIDENCE=medium
                     only keep proposals at or above this confidence (high,
                     medium, or low; default: low), applied after implied
                     tags are added
  DESC
  task propose: :environment do
    dry_run = ENV['DRY_RUN'] == '1'
    limit   = ENV['LIMIT']&.to_i
    offset  = ENV['OFFSET'].to_i
    abort 'OFFSET must not be negative' if offset.negative?
    ranks   = %w[genus species subspecies] # only these ranks are tagged
    if ENV['RANK'].present?
      unless ranks.include?(ENV['RANK'])
        abort "RANK must be one of: #{ranks.join(', ')}"
      end
      ranks = [ENV['RANK']]
    end
    levels = Tag::CONFIDENCE_LEVELS
    min_confidence = ENV['MIN_CONFIDENCE'].presence || levels.first
    unless levels.include?(min_confidence)
      abort "MIN_CONFIDENCE must be one of: #{levels.reverse.join(', ')}"
    end

    scope = Name
      .left_outer_joins(:name_tags)
      .where(name_tags: { id: nil })
      .where(status: 15) # Valid (SeqCode): validly published only
      .where(rank: ranks)
      .order('names.id')
      .offset(offset)
    scope = scope.limit(limit) if limit&.positive?
    # +find_each+ imposes its own ordering and ignores offset/limit, so
    # select the window's IDs first and iterate over those
    ids = scope.pluck('names.id')

    total    = ids.size
    proposed = 0
    skipped  = 0
    failed   = 0

    puts "Processing #{total} names#{ " (dry run)" if dry_run }..."
    puts "Backend: #{Rails.configuration.tagging_backend}"
    puts

    Name.where(id: ids).find_each do |name|
      proposals =
        TaggingService.propose(name).select do |p|
          levels.index(p['confidence']) >= levels.index(min_confidence)
        end

      if proposals.empty?
        puts "  #{name.name} (#{name.rank}): no tags proposed"
        skipped += 1
        next
      end

      slugs =
        proposals
          .map do |p|
            basis = p['basis'].present? ? ":#{p['basis']}" : ''
            basis += '; capped' if p['capped']
            implied =
              if p['implied_by'].blank? then ''
              elsif p['direct'] then "; also ←#{p['implied_by'].join('+')}"
              else "←#{p['implied_by'].join('+')}"
              end
            "#{p['slug']}(#{p['confidence'][0]}#{basis}#{implied})"
          end
          .join(', ')
      puts "  #{name.name} (#{name.rank}): #{slugs}"

      unless dry_run
        proposals.each do |proposal|
          tag = Tag.find_by(slug: proposal['slug'])
          next unless tag

          NameTag.find_or_create_by(name: name, tag: tag) do |nt|
            # The implied tags are proposals of their own, from Tag.expand
            nt.skip_implication_cascade = true
            nt.status_int  = 0  # proposed
            nt.proposed_by = 'llm'
            nt.notes       = "confidence: #{proposal['confidence']}"
            if proposal['basis'].present?
              nt.notes += "; basis: #{proposal['basis']}"
            end
            nt.notes += '; capped from high' if proposal['capped']
            if proposal['implied_by'].present?
              nt.notes += proposal['direct'] ? '; also' : ';'
              nt.notes += " implied by: #{proposal['implied_by'].join(', ')}"
            end
          end
        end
      end

      proposed += 1
    rescue TaggingService::Error => e
      $stderr.puts "  ERROR #{name.name}: #{e.message}" # +warn+ is muted by -W0
      failed += 1
    end

    puts
    puts "Done. Proposed: #{proposed}, skipped: #{skipped}, failed: #{failed}"
  end
end

