# Read App config.  Placed here to use from whenever (the "defined" part is also for it)
ac = YAML::load(File.open("#{defined?(RAILS_ROOT) ? RAILS_ROOT : '.'}/config/application.yml"))
env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
APP_CONFIG = ac[env.to_s]
