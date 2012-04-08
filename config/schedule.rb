# This will set up the environment into Rails.env
# Since we're inside the instance of a whenever object, we should access the Rails module in the global namespace
eval %Q(module ::Rails
  def self.env
    '#{@environment}' || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end
end
)

# Use this file to easily define all of your cron jobs.
require File.expand_path('../initializers/cache.rb',  __FILE__)
require File.expand_path('../initializers/appconfig.rb',  __FILE__)

app_url = APP_CONFIG['application_url'].gsub(/\/*$/,'')

# Commit each 30 seconds (as in config/initializers/cache.rb).  Cron doesn't allow this granularity, so we use a trick.
every 1.minute do
  # Commit information on the activity to the DB
  command %Q(curl #{app_url}/api/commit_activity)
  command %Q(sleep 30; curl #{app_url}/api/commit_activity)
end

# Commit post clicks
every 1.minute do
  post_click_api = %Q(curl #{app_url}/api/commit_clicks)
  (1.minute / POST_CLICK_CACHE_TIME).times {|m| command %Q(sleep #{POST_CLICK_CACHE_TIME*m}; #{post_click_api})}
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
