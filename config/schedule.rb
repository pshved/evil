# Use this file to easily define all of your cron jobs.
require File.expand_path('../initializers/cache.rb',  __FILE__)
require File.expand_path('../initializers/url.rb',  __FILE__)

app_url = THE_APPLICATION_URL.gsub(/\/*$/,'')

# Commit each 30 seconds (as in config/initializers/cache.rb).  Cron doesn't allow this granularity, so we use a trick.
every 1.minute do
  # Commit information on the activity to the DB
  command %Q(curl #{app_url}/api/commit_activity)
  command %Q(sleep 30; curl #{app_url}/api/commit_activity)
end

# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# Learn more: http://github.com/javan/whenever
