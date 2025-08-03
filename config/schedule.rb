#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end

every 20.minutes do
  rake 'genomes:save genomes:download'
end

every 1.day do
  rake 'works:update names:find parents:infer'
  rake 'wikidata:push'
end

every 1.month do
  runner 'ReminderMail.register_reminder'
  rake 'genomes:clean'
  rake 'strains:clean'
end

# IF CHANGED, don't forget to run:
# bundle exec whenever --update-crontab

# Learn more: http://github.com/javan/whenever
