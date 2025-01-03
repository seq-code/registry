namespace :genome_strain do
  desc 'Links all genome strain entries as Strain objects'
  task :update => :environment do |t, args|
    def usage(t)
      puts "Usage: rake genome_strain:update #{t}"
      exit 0
    end

    Name.where.not(genome_strain: [nil, ''])
        .where(nomenclatural_type_type: 'Genome')
        .each do |name|
      $stderr.puts('o %s' % name.name)
      strain = Strain.find_or_create_by(numbers_string: name.genome_strain)
      name.type_genome.update(strain: strain)
    end
  end
end
