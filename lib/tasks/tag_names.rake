namespace :tags do
  desc <<~DESC
    Propose tags for untagged names using the configured tagging backend.
    Only processes genera, species, and subspecies with no existing NameTag
    (of any status).
    Creates NameTag records with status: proposed, proposed_by: "llm".

    Options (set as ENV vars):
      LIMIT=50       process at most N names (default: all)
      DRY_RUN=1      print proposals without writing to the database
      RANK=genus     only process names of this rank (genus, species, or
                     subspecies)
  DESC
  task propose: :environment do
    dry_run = ENV['DRY_RUN'] == '1'
    limit   = ENV['LIMIT']&.to_i
    ranks   = %w[genus species subspecies] # only these ranks are tagged
    if ENV['RANK'].present?
      unless ranks.include?(ENV['RANK'])
        abort "RANK must be one of: #{ranks.join(', ')}"
      end
      ranks = [ENV['RANK']]
    end

    scope = Name
      .left_outer_joins(:name_tags)
      .where(name_tags: { id: nil })
      .where(status: 15) # Valid (SeqCode): validly published only
      .where(rank: ranks)
    scope = scope.limit(limit) if limit&.positive?

    total    = scope.count
    proposed = 0
    skipped  = 0
    failed   = 0

    puts "Processing #{total} names#{ " (dry run)" if dry_run }..."
    puts "Backend: #{Rails.configuration.tagging_backend}"
    puts

    scope.find_each do |name|
      proposals = TaggingService.propose(name)

      if proposals.empty?
        puts "  #{name.name} (#{name.rank}): no tags proposed"
        skipped += 1
        next
      end

      slugs =
        proposals
          .map { |p| "#{p['slug']}(#{p['confidence'].to_s[0]})" }
          .join(', ')
      puts "  #{name.name} (#{name.rank}): #{slugs}"

      unless dry_run
        proposals.each do |proposal|
          tag = Tag.find_by(slug: proposal['slug'])
          next unless tag

          NameTag.find_or_create_by(name: name, tag: tag) do |nt|
            nt.status_int  = 0  # proposed
            nt.proposed_by = 'llm'
            nt.notes       = "confidence: #{proposal['confidence']}"
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

