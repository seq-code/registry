
namespace :observers do
  desc 'Initializes name and register observers'
  task :init => :environment do |t, args|
    [Register, Name].each do |klass|
      $stderr.puts klass.to_s
      klass.all.each_with_index do |obj, k|
        $stderr.print " #{k} \r"
        obj.observers += obj.associated_users
      rescue ActiveRecord::RecordNotUnique
        true
      end
      $stderr.puts
    end
  end

end
