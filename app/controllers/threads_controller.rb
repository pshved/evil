class ThreadsController < ApplicationController
  caches_action :index, :unless => proc {current_user}, :expires_in => UNREG_VIEW_CACHE_TIME, :cache_path => proc {"index_#{params[:page]}"}

  filter_access_to :new
  def new
    if @source = Source.find_last_by_name(params[:src])
      # We're creating a thread in another forum
      @source_reply_to = 0
    else
      # We're creating a thread in this forum
      @thread = Threads.new
      @loginpost = Loginpost.new(:user => current_user)
    end
  end

  def index
    prepare_threads
  end

end
