
namespace :parents do
  desc 'Infers and links parents for orphan names'
  task :infer => :environment do |t, args|
    names = Name.where(parent: nil)
                .where.not(rank: [nil, ''])
                .where('status < 15')
    names.each do |name|
      parent = nil
      case name.rank
      when 'subspecies'
        expected = name.base_name.sub(/ subsp?\. .*/, '')
        parent = Name.where(name: [expected, "Candidatus #{expected}"]).first
      when 'species'
        expected = name.base_name.sub(/ .*/, '')
        parent = Name.where(name: [expected, "Candidatus #{expected}"]).first
      when 'genus'
        if suff = Name.rank_suffixes[name.expected_parent_rank.to_sym]
          3.times do |i|
            root = name.base_name.sub(/.{#{i}}$/, '')
            parent = Name.where('name LIKE ?', "#{root}%#{suff}").first
            parent ||=
              Name.where('name LIKE ?', "Candidatus #{root}%#{suff}").first
            break if parent
          end
        end
      else
        root = name.base_name.sub(/#{name.rank_suffix}$/, '')
        if suff = Name.rank_suffixes[name.expected_parent_rank.to_sym]
          parent = Name.where('name LIKE ?', "#{root}%#{suff}").first
          parent ||=
            Name.where('name LIKE ?', "Candidatus #{root}%#{suff}").first
        end
      end

      if parent
        puts "~ #{name.name} -> #{parent.name}"
        name.update(parent: parent)
      end
    end
  end

end
