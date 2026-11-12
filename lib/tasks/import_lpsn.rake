
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
    bypassed_names = {} # record_no => id of the name to link to instead
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
      else # LPSN only has genera, species, and subspecies
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

      # Check first the current name record
      name = Name.find_or_create_by(name: pars[:name])
      if name.status > 5 && name.status < 20
        warn "- Name in SeqCode, bypassing: #{name.name}"
        bypassed_names[row['record_no']] = name.id
        next
      end
      if name.status > 20
        warn "- Name in a different code, bypassing: #{name.name}"
        bypassed_names[row['record_no']] = name.id
        next
      end
      if name.redirect_id.present?
        warn "- Name is deprecated, bypassing: #{name.name}"
        bypassed_names[row['record_no']] = name.redirect_id
        next
      end
      name.protect_from_lpsn.to_s.split(',').each do |i|
        pars.delete(i.to_sym)
        parent = nil if i == 'parent'
        row['record_lnk'] = nil if i == 'correct_name'
      end

      # Save data
      name.update!(pars)
      parsed_names[row['record_no']] = {
        name_id: name.id, parent: parent, correct_name: row['record_lnk'],
        type_name: type_name
      }
    end # CSV.foreach
    $stderr.puts

    # Second pass, linking all names
    $stderr.puts 'Linking names'
    linked_id = lambda do |record_no|
      parsed_names[record_no]&.dig(:name_id) || bypassed_names[record_no]
    end
    parsed_names.each_value.each_with_index do |entry, k|
      $stderr.print "- #{k} \r"
      # parent, correct_name, type_name
      pars = {}
      if entry[:parent].present?
        pars[:parent_id] = Name.find_by(entry[:parent])&.id
      end
      if entry[:correct_name].present?
        if (id = linked_id.(entry[:correct_name]))
          pars[:correct_name_id] = id
        else
          warn "- Correct name not in parsed names: #{entry[:name_id]} " \
               "(#{entry[:correct_name]})"
        end
      end
      if entry[:type_name].present?
        if (id = linked_id.(entry[:type_name]))
          pars[:nomenclatural_type_type] = 'Name'
          pars[:nomenclatural_type_id] = id
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
