class ThreadsController < ApplicationController
  filter_access_to :new
  def new
    @thread = Threads.new
    @loginpost = Loginpost.new(:user => current_user)
  end

  def index
    prepare_threads
  end

end
