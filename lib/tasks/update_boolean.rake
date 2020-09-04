
namespace :beta do
  task :update_boolean => :environment do |t, args|
    bools = {
      User: %i[admin contributor]
    }

    bools.each do |k, v|
      klass = Object.const_get(k)
      v.each do |i|
        klass.where("#{i} = 't'").update_all(i => 1)
        klass.where("#{i} = 'f'").update_all(i => 0)
      end
    end
  end
end
