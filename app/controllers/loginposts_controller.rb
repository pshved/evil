require 'autoload/utils'

class LoginpostsController < ApplicationController
  before_filter :new_loginpost_from_params, :only => [:create]
  filter_access_to :create, :attribute_check => true

  # POST /loginposts
  def create
    @loginpost.post.host = gethostbyaddr(request.remote_ip)
    respond_to do |format|
      if @loginpost.save
        @loginpost.log_in_if_necessary
        format.html { redirect_to @loginpost.saved_post, notice: 'Post was successfully created.' }
      else
        format.html { render action: "new" }
      end
    end
  end

  def new_loginpost_from_params
    @loginpost = Loginpost.new(params[:loginpost].merge(:user => current_user))
  end

end

