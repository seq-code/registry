#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end

every 1.week do
  rake 'works:update names:find parents:infer'
end

# IF CHANGED, don't forget to run:
# bundle exec whenever --update-crontab

# Learn more: http://github.com/javan/whenever
