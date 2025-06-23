
require 'csv'

namespace :lpsn do
  desc 'Marks changes as protected from LPSN for future updates'
  task :protect, [:csv] => :environment do |t, args|
    def usage(t)
      puts "Usage: rake #{t}[lpsn_gss.csv]"
      exit 0
    end

    usage(t) unless args[:csv]
    # First pass, discard repeats
    $stderr.puts "Parsing CSV: #{args[:csv]}"
    names = {}
    CSV.foreach(args[:csv], headers: true).each_with_index do |row, k|
      n = [row['genus_name'], row['sp_epithet'], row['subsp_epithet']]
      names[n] = k
    end

    # Second pass, actually do work
    CSV.foreach(args[:csv], headers: true).each_with_index do |row, k|
      $stderr.print "- #{k} \r"

      # Discard repeats
      n = [row['genus_name'], row['sp_epithet'], row['subsp_epithet']]
      next unless names[n] == k

      # Get data
      pars = { name: row['genus_name'] }
      parent = nil
      if row['sp_epithet'].present?
        parent = { name: pars[:name] }
        pars[:name] = pars[:name] + ' ' + row['sp_epithet']
        if row['subsp_epithet'].present?
          parent = { name: pars[:name] }
          pars[:name] = pars[:name] + ' subsp. ' + row['subsp_epithet']
        end
      end
      status = row['status'].split('; ')
      pars[:proposal_kind] = status[1] if status[1].present?
      pars[:nomenclatural_status] = status[2] if status[2].present?
      pars[:taxonomic_status] = status[3] if status[3].present?
      pars[:authority] = row['authors']

      # Save data
      name = Name.find_by(name: pars[:name])
      next unless name.present?
      next if name.status > 5 && name.status < 20
      next if name.status > 20

      protect = Set.new(name.protect_from_lpsn.to_s.split(','))
      %i[
        proposal_kind nomenclatural_status taxonomic_status authority
      ].each do |i|
        protect << i.to_s if name.send(i).to_s != pars[i].to_s
      end
      if row['record_lnk'].present? && (
              protect.include?('nomenclatural_status') ||
              protect.include?('taxonomic_status')
            )
        protect << 'correct_name'
      end
      if parent.present? && name.parent.present? &&
            !name.parent.is_variant?(parent[:name])
        protect << 'parent'
      end
      unless protect.empty?
        warn "- Protecting: #{name.name}: #{protect.join(', ')}"
        name.update_column(:protect_from_lpsn, protect.join(','))
      end
    end # CSV.foreach
    $stderr.puts
  end

end
