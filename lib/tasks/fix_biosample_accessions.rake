namespace :sequencing_experiments do
  desc 'Backfill biosample_accession values that were stored as an ENA/SRA ' \
       'Sample accession (SRS/ERS/DRS) instead of the true BioSample ' \
       'accession, then relink affected genomes'
  task fix_biosample_accessions: :environment do
    affected =
      SequencingExperiment.where("biosample_accession ~* '^(SRS|ERS|DRS)[0-9]+$'")
    total = affected.count
    $stderr.puts "Found #{total} sequencing experiments to reprocess"

    fixed = 0
    affected.find_each do |experiment|
      before = experiment.biosample_accession
      experiment.external_sra_to_biosample!
      if experiment.biosample_accession != before
        experiment.save!
        fixed += 1
        $stderr.puts "o #{experiment.sra_accession}: #{before} -> #{experiment.biosample_accession}"
      else
        $stderr.puts "- #{experiment.sra_accession}: could not resolve, left as #{before}"
      end
    end
    $stderr.puts "Fixed #{fixed} of #{total} sequencing experiments"

    $stderr.puts 'Relinking genomes...'
    relinked = 0
    Genome.where.not(source_json: nil).find_each do |genome|
      before_ids = genome.sequencing_experiments.pluck(:id).sort
      genome.send(:link_sequencing_experiments!)
      after_ids = genome.sequencing_experiments.reload.pluck(:id).sort
      next if before_ids == after_ids

      relinked += 1
      $stderr.puts "o #{genome.text}: #{before_ids} -> #{after_ids}"
    end
    $stderr.puts "Relinked #{relinked} genomes"
  end
end
