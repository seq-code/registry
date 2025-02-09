
namespace :genomes do
  desc 'Find and remove genomes that are not associated to any name'
  task :clean => :environment do |t, args|
    Genome.includes(:typified_names)
          .where('genomes.updated_at < ?', 6.months.ago)
          .where.missing(:typified_names)
          .each do |genome|
      next if genome.strain.try(:typified_names).present?

      puts '~ Removing %s - %s - Updated %s' % [
        genome.title(''), genome.text, genome.updated_at
      ]
      genome.destroy
    end
  end

end
