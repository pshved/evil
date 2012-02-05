class Admin::ConfigurablesController < ApplicationController
  # include the engine controller actions, as noted on https://github.com/paulca/configurable_engine
  include ConfigurableEngine::ConfigurablesController

  # Since all actions are only visible to admins, do not distinguish permissions
  filter_access_to :all, :require => :manage
end
