# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Zlo::Application.initialize!

# Passenger and memcached integration (see https://github.com/mperham/dalli)
if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    # Reset Rails's object cache
    # Only works with DalliStore
    Rails.cache.reset if forked
  end
end
