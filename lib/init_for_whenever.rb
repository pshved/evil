# When whenever generates crontab, Rails doesn't load environment. We need this to read app_config.
# Here's the reimplementation of the Rails' native method

module Rails
  def self.env
    # Taken from Rails itself
    ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end
end

