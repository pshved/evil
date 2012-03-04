source 'http://rubygems.org'

gem 'rails', '3.1.3'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

# I"m not going to use sqlite
# gem 'sqlite3'
#gem 'activerecord-mysql-adapter'
gem 'mysql'
gem 'mysql2'


# JavaScript Runtimes.  Have no idea what they are
gem 'execjs'
gem 'therubyracer'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.1.5'
  gem 'coffee-rails', '~> 3.1.1'
  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails'

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
gem 'capistrano'

group :test do
  # Pretty printed test output
  gem 'turn', '~> 0.8.3', :require => false
  # To use debugger
  # Couldn't install under ruby 1.9.  Temporarily commenting
  #gem 'ruby-debug19', :require => nil
end

# Only in development!
group :development do
  gem 'ruby-debug19'
end

gem 'haml'

# Authentication
gem 'authlogic'

gem 'treetop'

gem 'declarative_authorization'

gem 'enum_column3'

# Pagination
gem 'kaminari'

# To handle global config settings
gem 'configurable_engine'

group :test do
   gem 'minitest', '>1.6'
   gem 'ruby-prof'
end

gem 'tzinfo'

gem 'libxml-ruby'

# Captcha
gem "recaptcha", :require => "recaptcha/rails"

# Thread/fork spawner
gem 'spawn', :git => 'git://github.com/tra/spawn', :branch => 'edge'

# Caching (memcached)
gem 'dalli'
