#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end

every 1.day do
  rake 'works:update names:find parents:infer'
end

# Learn more: http://github.com/javan/whenever
