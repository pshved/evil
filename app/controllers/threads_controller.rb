class ThreadsController < ApplicationController
  def new
    @thread = Threads.new
    @loginpost = Loginpost.new(:user => current_user)
  end

  def create
  end

  def index
    # TODO: stub
    @threads = Threads.all
    # We do not set up parent, so the login post is new.
    @loginpost = Loginpost.new(:user => current_user)
  end

end
