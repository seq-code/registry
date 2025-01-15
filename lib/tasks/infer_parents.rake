
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
        parent = Name.find_by_variants(expected)
      when 'species'
        expected = name.base_name.sub(/ .*/, '')
        parent = Name.find_by_variants(expected)
      else
        stem = name.stem
        suff = Name.rank_suffixes[name.expected_parent_rank.to_sym]
        if stem.present? && suff.present?
          parent = Name.find_by_variants("#{stem}#{suff}")
        end
      end

      if parent
        puts "~ #{name.name} -> #{parent.name}"
        name.update(parent: parent)
      end
    end
  end

end
