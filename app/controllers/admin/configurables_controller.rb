class Admin::ConfigurablesController < ApplicationController
  # include the engine controller actions, as noted on https://github.com/paulca/configurable_engine
  include ConfigurableEngine::ConfigurablesController

  # Since all actions are only visible to admins, do not distinguish permissions
  filter_access_to :all, :require => :manage

  # Add cache invalidation to the update method
  alias_method :config_update, :update
  def update
    clear_config_cache
    config_update
  end
end
