class LoginpostsController < ApplicationController
  def new
    @loginpost = Loginpost.new
  end

  # POST /loginposts
  def create
    @loginpost = Loginpost.new(params[:loginpost])

    respond_to do |format|
      if @loginpost.save
        @loginpost.log_in_if_necessary
        format.html { redirect_to @loginpost.saved_post, notice: 'Post was successfully created.' }
      else
        format.html { render action: "new" }
      end
    end
  end

end

