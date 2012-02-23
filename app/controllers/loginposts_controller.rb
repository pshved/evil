require 'autoload/utils'

class LoginpostsController < ApplicationController
  before_filter :new_loginpost_from_params, :only => [:create]
  filter_access_to :create, :attribute_check => true

  # POST /loginposts
  def create
    @loginpost.post.host = gethostbyaddr(request.remote_ip)
    if params[:commit] == 'Preview'
      # This is a preview, validate and show it
      @loginpost.valid?
      @post = @loginpost.post
      puts @post.body
      respond_to do |format|
        flash[:notice] = 'This is a preview only!'
        format.html { render action: "new" }
      end
    else
      respond_to do |format|
        if captcha_ok? && @loginpost.save
          # TODO: oops, race condition between post save and logging in!
          @loginpost.log_in_if_necessary
          format.html { redirect_to @loginpost.saved_post, notice: 'Post was successfully created.' }
        else
          @post = @loginpost.post
          format.html { render action: "new" }
        end
      end
    end
  end

  def new_loginpost_from_params
    @loginpost = Loginpost.new(params[:loginpost].merge(:user => current_user))
  end

end

