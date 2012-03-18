namespace :cache do
  desc 'Clear memcache'
  task :clear => :environment do
    Rails.cache.clear
  end
end
# Thanks to http://www.strictlyuntyped.com/ for the code that works.


