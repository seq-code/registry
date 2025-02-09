
namespace :strains do
  desc 'Find and remove strains that are not associated to any name'
  task :clean => :environment do |t, args|
    Strain.includes(:typified_names)
          .where('strains.updated_at < ?', 6.months.ago)
          .where.missing(:typified_names)
          .each do |strain|
      next if strain.genomes.any? { |g| g.typified_names.present? }

      puts '~ Removing %s - %s - Updated %s' % [
        strain.title(''), strain.numbers_string, strain.updated_at
      ]
      strain.destroy
    end
  end

end
