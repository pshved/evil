require 'autoload/utils'

class LoginpostsController < ApplicationController
  before_filter :new_loginpost_from_params, :only => [:create]
  filter_access_to :create, :attribute_check => true

  # POST /loginposts
  def create
    @loginpost.post.host = gethostbyaddr(request.remote_ip)
    if ! params[:preview].blank?
      # This is a preview, validate and show it
      @loginpost.valid?
      @post = @loginpost.post
      puts @post.body
      respond_to do |format|
        flash[:notice] = t('notice.preview')
        format.html { render action: "new" }
      end
    else
      respond_to do |format|
        # Do not check captcha on validation failure: user should be able to first complete the form correctly without solving the captcha.
        if @loginpost.valid? && captcha_ok? && @loginpost.save
          # TODO: oops, race condition between post save and logging in!
          @loginpost.log_in_if_necessary
          format.html { redirect_to @loginpost.saved_post, notice: t('notice.posted') }
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

