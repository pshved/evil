require "bundler/capistrano"

set :application, "xboard"
set :repository,  "git@coldattic.info:evil.git"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

role :web, "x.coldattic.info"                          # Your HTTP server, Apache/etc
role :app, "x.coldattic.info"                          # This may be the same as your `Web` server
role :db,  "x.coldattic.info", :primary => true # This is where Rails migrations will run

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

set :deploy_to, '/var/www/xboard'
set :user, 'zlowik'
# Capistrano doesn't seem to have group setting...
after 'deploy:update_code', 'deploy:chown'
namespace :deploy do
  desc "Changes group to www-data"
  task :chown, :roles => [ :app, :db, :web ] do
    run "chown -R #{user}:www-data #{deploy_to}"
  end
end
set :group_writable, true
# Do not need sudo, as our user is ok without that.
set :use_sudo, false

# Clear cache at deployment
after 'deploy:update_code', 'clear_cache'
task :clear_cache do
  run "RAILS_ENV=production rake cache:clear"
end

after 'deploy:update_code', 'deploy:symlink_cfg'
namespace :deploy do
  desc "Symlinks config files"
  task :symlink_cfg, :roles => :app do
    run "ln -nfs #{deploy_to}/shared/config/database.yml #{release_path}/config/database.yml"
  end
end

load "deploy/assets"




