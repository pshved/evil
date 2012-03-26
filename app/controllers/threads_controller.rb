class ThreadsController < ApplicationController
  caches_action :index, :unless => proc {current_user}, :expires_in => UNREG_VIEW_CACHE_TIME, :cache_path => proc {"index_#{params[:page]}"}

  filter_access_to :new
  def new
    @thread = Threads.new
    @loginpost = Loginpost.new(:user => current_user)
  end

  def index
    prepare_threads
  end

end
