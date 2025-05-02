
require 'csv'

namespace :lpsn do
  desc 'Imports ICNP names from an LPSN-formatted CSV'
  task :import, [:csv] => :environment do |t, args|
    def usage(t)
      puts "Usage: rake #{t}[lpsn_gss.csv]"
      exit 0
    end

    usage(t) unless args[:csv]
    # First pass, saving or retrieving all names
    $stderr.puts "Parsing CSV: #{args[:csv]}"
    parsed_names = {}
    CSV.foreach(args[:csv], headers: true).each_with_index do |row, k|
      $stderr.print "- #{k} \r"
      # Define full name and rank
      pars = { rank: 'genus', name: row['genus_name'] }
      parent = nil
      if row['sp_epithet'].present?
        pars[:rank] = 'species'
        parent = { rank: 'genus', name: pars[:name] }
        pars[:name] = pars[:name] + ' ' + row['sp_epithet']
        if row['subsp_epithet'].present?
          pars[:rank] = 'subspecies'
          parent = { rank: 'species', name: pars[:name] }
          pars[:name] = pars[:name] + ' subsp. ' + row['subsp_epithet']
        end
      end

      # Nomenclatural type
      type_name = nil
      if pars[:rank] == 'genus'
        type_name = row['nomenclatural_type']
      else
        pars[:nomenclatural_type_type] = 'Strain'
        pars[:nomenclatural_type_entry] =
          row['nomenclatural_type'].gsub('; ', ' = ')
      end

      # All additional data
      status = row['status'].split('; ')
      pars[:proposal_kind] = status[1] if status[1].present?
      pars[:nomenclatural_status] = status[2] if status[2].present?
      pars[:taxonomic_status] = status[3] if status[3].present?
      pars[:authority] = row['authors']
      pars[:lpsn_url] = row['address']
      pars[:status] = 20

      # Save data
      name = Name.find_or_create_by(name: pars[:name])
      if name.status > 5 && name.status < 20
        warn "- Name in SeqCode, bypassing: #{name.name}"
        next
      end
      if name.status > 20
        warn "- Name in a different code, bypassing: #{name.name}"
        next
      end
      name.update!(pars)
      parsed_names[row['record_no']] = {
        name_id: name.id, parent: parent, correct_name: row['record_lnk'],
        type_name: type_name
      }
    end # CSV.foreach
    $stderr.puts

    # Second pass, linking all names
    $stderr.puts 'Linking names'
    parsed_names.each_value.each_with_index do |entry, k|
      $stderr.print "- #{k} \r"
      # parent, correct_name, type_name
      pars = {}
      if entry[:parent].present?
        pars[:parent_id] = Name.find_by(entry[:parent])&.id
      end
      if entry[:correct_name].present?
        pars[:correct_name_id] = parsed_names[entry[:correct_name]][:name_id]
      end
      if entry[:type_name].present?
        if parsed_names[entry[:type_name]].present?
          pars[:nomenclatural_type_type] = 'Name'
          pars[:nomenclatural_type_id] =
            parsed_names[entry[:type_name]][:name_id]
        else
          warn "- Type name not in parsed names: #{entry[:name_id]} " + 
               "(#{entry[:type_name]})"
        end
      end
      Name.find(entry[:name_id]).update(pars) unless pars.empty?
    end

    $stderr.puts "Parsed #{parsed_names.size} names"
  end

end
