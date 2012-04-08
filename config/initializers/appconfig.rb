# Read App config.  Placed here to use from whenever (the "defined" part is also for it)
ac = YAML::load(File.open("#{defined?(RAILS_ROOT) ? RAILS_ROOT : '.'}/config/application.yml"))
APP_CONFIG = ac[Rails.env.to_s]
