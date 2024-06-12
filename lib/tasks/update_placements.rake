
namespace :placements do
  task :ensure_consistency => :environment do |t, args|
    n = Name.all.count
    k = 0
    $stderr.puts "Traversing #{n} names"
    names = Name.all.includes(:placements).references(:placements)
    names.each_with_index do |name, k|
      $stderr.print "> #{k+1}/#{n}   \r"
      next if name.consistent_placement?
      name.ensure_consistent_placement!
      k += 1
    end
    $stderr.puts
    $stderr.puts "Fixed #{k} names"
  end
end
